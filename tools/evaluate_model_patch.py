#!/usr/bin/env python3
"""Run a case evaluator through Docker on Windows, Linux, or macOS."""

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Optional, Sequence


CASE_PATTERN = re.compile(r"^javac_case_(\d{3})$")


def write_text_lf(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write(content)


def parse_args(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Evaluate a model patch with a Docker Hub SWE-bench case image."
    )
    parser.add_argument(
        "--case-dir",
        required=True,
        type=Path,
        help="Path to javac_case_NNN.",
    )
    parser.add_argument(
        "--image",
        required=True,
        help="Docker evaluator image, for example yutu0814/javac-case-092-jep:model-evaluator.",
    )
    parser.add_argument(
        "--patch",
        required=True,
        type=Path,
        help="Path to the model-generated .diff file.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="Result JSON path. Defaults to case-dir/verification/evaluator/model_patch_summary.json.",
    )
    parser.add_argument(
        "--docker",
        default="docker",
        help="Docker executable name or path. Defaults to docker.",
    )
    parser.add_argument(
        "--pull",
        action="store_true",
        help="Pull the evaluator image before running it.",
    )
    return parser.parse_args(argv)


def run_command(command: Sequence[str], log_path: Path) -> subprocess.CompletedProcess:
    result = subprocess.run(
        list(command),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
    )
    write_text_lf(
        log_path,
        result.stdout + result.stderr,
    )
    return result


def write_fallback_result(output_path: Path, case_name: str, reason: str) -> None:
    write_text_lf(
        output_path,
        json.dumps(
            {
                "instance_id": case_name,
                "status": "failed",
                "reason": reason,
                "test_exit_code": None,
            },
            indent=2,
        )
        + "\n",
    )


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = parse_args(argv)
    case_dir = args.case_dir.expanduser().resolve()
    patch_path = args.patch.expanduser().resolve()
    case_name = case_dir.name
    match = CASE_PATTERN.match(case_name)

    if not match:
        raise SystemExit("--case-dir must end with javac_case_NNN")
    if not case_dir.is_dir():
        raise SystemExit("Case directory does not exist: {}".format(case_dir))
    if not patch_path.is_file():
        raise SystemExit("Model patch does not exist: {}".format(patch_path))
    if shutil.which(args.docker) is None:
        raise SystemExit("Docker executable was not found: {}".format(args.docker))

    output_path = (
        args.output.expanduser().resolve()
        if args.output
        else case_dir / "verification" / "evaluator" / "model_patch_summary.json"
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    if output_path.exists():
        output_path.unlink()

    log_dir = output_path.parent
    build_log = log_dir / "docker_pull.log"
    run_log = log_dir / "docker_run.log"
    container_root = "/opt/{}".format(case_name)
    container_patch = container_root + "/model_patch.diff"
    container_results = container_root + "/host_results"
    container_result = container_results + "/" + output_path.name
    container_name = "{}-model-eval".format(case_name.replace("_", "-"))

    if args.pull:
        pull = run_command([args.docker, "pull", args.image], build_log)
        if pull.returncode != 0:
            write_fallback_result(output_path, case_name, "docker_pull_failed")
            print(pull.stdout, end="")
            print(pull.stderr, end="", file=sys.stderr)
            return 2

    patch_mount = "type=bind,source={},target={},readonly".format(
        patch_path, container_patch
    )
    output_mount = "type=bind,source={},target={}".format(
        output_path.parent, container_results
    )
    command = [
        args.docker,
        "run",
        "--rm",
        "--name",
        container_name,
        "--mount",
        patch_mount,
        "--mount",
        output_mount,
        "--env",
        "MODEL_PATCH_PATH={}".format(container_patch),
        "--env",
        "RESULT_DIR={}".format(container_results),
        "--env",
        "RESULT_PATH={}".format(container_result),
        args.image,
    ]
    run = run_command(command, run_log)
    print(run.stdout, end="")
    print(run.stderr, end="", file=sys.stderr)

    if not output_path.is_file():
        write_fallback_result(output_path, case_name, "container_failed_before_result")
        print("Result JSON was not produced: {}".format(output_path), file=sys.stderr)
        return 2

    try:
        result = json.loads(output_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        print("Invalid evaluator result: {}".format(error), file=sys.stderr)
        return 2

    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0 if result.get("status") == "resolved" else 1


if __name__ == "__main__":
    sys.exit(main())
