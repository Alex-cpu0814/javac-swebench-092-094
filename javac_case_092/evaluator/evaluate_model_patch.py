#!/usr/bin/env python3
"""Evaluate one candidate patch in a configured clean benchmark image."""

from __future__ import print_function

import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

from logging_v3 import (
    EventLogger,
    SCHEMA_VERSION,
    decode_output,
    new_identifier,
    utc_now,
    write_json,
    write_text,
)


SAFE_ID = re.compile(r"^[A-Za-z0-9._-]+$")
TEST_LINE = re.compile(
    r"^(?P<method>\S+) \((?P<class>[^)]+)\) \.\.\. "
    r"(?P<status>ok|FAIL|ERROR|skipped(?: .*)?)$"
)


def sha256_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_json(path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def absolute_path(path):
    return Path(os.path.abspath(str(path.expanduser())))


def docker_mount(source, target, readonly=False):
    value = "type=bind,source={},target={}".format(source, target)
    return value + (",readonly" if readonly else "")


def normalize_status(raw_status):
    if raw_status == "ok":
        return "PASSED"
    if raw_status == "FAIL":
        return "FAILED"
    if raw_status == "ERROR":
        return "ERROR"
    if raw_status.startswith("skipped"):
        return "SKIPPED"
    return "UNKNOWN"


def parse_test_log(text):
    statuses = {}
    for raw_line in text.splitlines():
        match = TEST_LINE.match(raw_line.strip())
        if not match:
            continue
        test_id = "{}.{}".format(match.group("class"), match.group("method"))
        statuses[test_id] = normalize_status(match.group("status"))
    return statuses


def expected_report(expected_ids, observed):
    return {test_id: observed.get(test_id, "MISSING") for test_id in expected_ids}


def compact_counts(report):
    counts = Counter(report.values())
    return {
        "expected": len(report),
        "passed": counts.get("PASSED", 0),
        "failed": counts.get("FAILED", 0) + counts.get("ERROR", 0),
        "skipped": counts.get("SKIPPED", 0),
        "missing": counts.get("MISSING", 0),
    }


def inspect_image(docker, image):
    output = decode_output(subprocess.check_output(
        [docker, "image", "inspect", image], stderr=subprocess.STDOUT
    ))
    item = json.loads(output)[0]
    return {
        "name": image,
        "id": item.get("Id"),
        "repo_digests": item.get("RepoDigests") or [],
    }


def load_config(path):
    config = load_json(path)
    required = (
        "case_number", "instance_id", "instance_file", "base_commit",
        "image", "runtime_assets",
    )
    missing = [key for key in required if key not in config]
    if missing:
        raise SystemExit("Missing case config keys: {}".format(", ".join(missing)))
    return config


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--patch", required=True, type=Path)
    parser.add_argument("--case-dir", type=Path)
    parser.add_argument("--image")
    parser.add_argument("--output-root", type=Path)
    parser.add_argument("--run-id")
    parser.add_argument("--label")
    parser.add_argument("--timeout", type=int, default=1800)
    parser.add_argument("--docker", default="docker")
    parser.add_argument(
        "--log-level", choices=("DEBUG", "INFO", "WARN", "ERROR"),
        default="INFO",
    )
    args = parser.parse_args(argv)

    if args.timeout <= 0:
        raise SystemExit("Timeout must be greater than zero")
    run_id = args.run_id or new_identifier("run")
    if not SAFE_ID.match(run_id):
        raise SystemExit("Invalid run id: {}".format(run_id))

    script_evaluator_dir = absolute_path(Path(__file__)).parent
    case_dir = absolute_path(args.case_dir) if args.case_dir else script_evaluator_dir.parent
    evaluator_dir = case_dir / "evaluator"
    config_path = evaluator_dir / "case_config.json"
    if not config_path.is_file():
        raise SystemExit("Missing case config: {}".format(config_path))
    config = load_config(config_path)
    image = args.image or config["image"]
    patch_path = absolute_path(args.patch)
    instance_path = case_dir / Path(config["instance_file"])
    test_patch_path = case_dir / "patches" / "test_patch.diff"
    shell_runner = evaluator_dir / "run_evaluation.sh"
    runtime_assets = []
    for asset in config["runtime_assets"]:
        source = case_dir / Path(asset["source"])
        target = asset["target"]
        if not target.startswith("/benchmark/"):
            raise SystemExit("Invalid runtime asset target: {}".format(target))
        runtime_assets.append((source, target))
    runs_dir = (
        absolute_path(args.output_root)
        if args.output_root else case_dir / "verification" / "runs"
    )
    run_dir = runs_dir / run_id
    try:
        run_dir.mkdir(parents=True, exist_ok=False)
    except FileExistsError:
        raise SystemExit("Run directory already exists: {}".format(run_dir))

    logger = EventLogger(run_dir / "events.jsonl", run_id, args.log_level)
    started_at = utc_now()
    started_clock = time.monotonic()
    image_info = {"name": image, "id": None, "repo_digests": []}
    container_exit_code = None
    timed_out = False

    def finish(status, reason, phase, grading_summary, exit_code):
        duration_ms = int((time.monotonic() - started_clock) * 1000)
        logger.emit(
            "INFO" if status == "resolved" else (
                "WARN" if status == "unresolved" else "ERROR"
            ),
            "grading", "evaluation.completed",
            "Evaluation finished with status {}".format(status),
            status=status, reason=reason, exit_code=exit_code,
            duration_ms=duration_ms,
        )
        summary = {
            "schema_version": SCHEMA_VERSION,
            "kind": "patch_evaluation",
            "run_id": run_id,
            "label": args.label,
            "instance_id": phase.get("instance_id", config["instance_id"]),
            "status": status,
            "reason": reason,
            "started_at": started_at,
            "finished_at": utc_now(),
            "duration_ms": duration_ms,
            "application_order": ["model_patch", "test_patch", "tests"],
            "model_patch_sha256": (
                sha256_file(patch_path) if patch_path.is_file() else None
            ),
            "test_patch_sha256": (
                sha256_file(test_patch_path) if test_patch_path.is_file() else None
            ),
            "image": image_info,
            "container_exit_code": container_exit_code,
            "phase": phase,
            "grading": grading_summary,
            "logs": {
                "events": "events.jsonl",
                "docker_stdout": (
                    "docker-run.stdout.raw.log"
                    if (run_dir / "docker-run.stdout.raw.log").is_file() else None
                ),
                "docker_stderr": (
                    "docker-run.stderr.raw.log"
                    if (run_dir / "docker-run.stderr.raw.log").is_file() else None
                ),
                "model_patch": (
                    "model-patch.raw.log"
                    if (run_dir / "model-patch.raw.log").is_file() else None
                ),
                "test_patch": (
                    "test-patch.raw.log"
                    if (run_dir / "test-patch.raw.log").is_file() else None
                ),
                "project_build": (
                    "project-build.raw.log"
                    if (run_dir / "project-build.raw.log").is_file() else None
                ),
                "tests": (
                    "tests.raw.log" if (run_dir / "tests.raw.log").is_file() else None
                ),
                "grading": (
                    "grading.json" if (run_dir / "grading.json").is_file() else None
                ),
            },
        }
        write_json(run_dir / "summary.json", summary)
        write_json(runs_dir / "latest.json", {
            "schema_version": SCHEMA_VERSION,
            "run_id": run_id,
            "summary": "{}/summary.json".format(run_id),
        })
        return exit_code

    logger.emit(
        "INFO", "preflight", "evaluation.started",
        "Starting candidate patch evaluation", image=image,
        instance_id=config["instance_id"],
        label=args.label, timeout_seconds=args.timeout,
    )
    required = [patch_path, instance_path, test_patch_path, shell_runner]
    required.extend(source for source, unused_target in runtime_assets)
    missing = [str(path) for path in required if not path.is_file()]
    empty_grading = {
        "tests_observed": 0,
        "FAIL_TO_PASS": {"expected": 0, "passed": 0, "failed": 0, "skipped": 0, "missing": 0},
        "PASS_TO_PASS": {"expected": 0, "passed": 0, "failed": 0, "skipped": 0, "missing": 0},
        "unexpected_failures": 0,
    }
    if missing:
        logger.emit(
            "ERROR", "preflight", "asset.missing",
            "Required evaluation assets are missing", missing=missing,
        )
        phase = {"phase": "preflight", "outcome": "infrastructure_error", "reason": "required_asset_missing", "test_exit_code": None}
        return finish("error", "required_asset_missing", phase, empty_grading, 2)
    if shutil.which(args.docker) is None:
        logger.emit(
            "ERROR", "preflight", "docker.missing",
            "Docker executable was not found", executable=args.docker,
        )
        phase = {"phase": "preflight", "outcome": "infrastructure_error", "reason": "docker_not_found", "test_exit_code": None}
        return finish("error", "docker_not_found", phase, empty_grading, 2)

    instance = load_json(instance_path)
    empty_grading["FAIL_TO_PASS"]["expected"] = len(instance.get("FAIL_TO_PASS", []))
    empty_grading["FAIL_TO_PASS"]["missing"] = len(instance.get("FAIL_TO_PASS", []))
    empty_grading["PASS_TO_PASS"]["expected"] = len(instance.get("PASS_TO_PASS", []))
    empty_grading["PASS_TO_PASS"]["missing"] = len(instance.get("PASS_TO_PASS", []))
    try:
        image_info.update(inspect_image(args.docker, image))
    except (subprocess.CalledProcessError, ValueError, KeyError, IndexError) as error:
        logger.emit(
            "ERROR", "preflight", "image.inspect_failed",
            "Evaluator image is unavailable or invalid", detail=str(error),
        )
        phase = {"phase": "preflight", "outcome": "infrastructure_error", "reason": "image_unavailable", "test_exit_code": None, "instance_id": instance.get("instance_id")}
        return finish("error", "image_unavailable", phase, empty_grading, 2)

    container_suffix = hashlib.sha256(run_id.encode("utf-8")).hexdigest()[:12]
    container_name = "javac-case-{}-eval-{}".format(
        config["case_number"], container_suffix
    )
    command = [
        args.docker, "run", "--rm", "--name", container_name,
        "--network", "none", "--cap-drop", "ALL",
        "--security-opt", "no-new-privileges",
        "--env", "BENCHMARK_RUN_ID={}".format(run_id),
        "--env", "BENCHMARK_BASE_COMMIT={}".format(config["base_commit"]),
        "--mount", docker_mount(patch_path, "/inputs/model.patch", True),
        "--mount", docker_mount(test_patch_path, "/inputs/test.patch", True),
        "--mount", docker_mount(shell_runner, "/benchmark/run_evaluation.sh", True),
    ]
    for source, target in runtime_assets:
        command.extend(["--mount", docker_mount(source, target, True)])
    command.extend([
        "--mount", docker_mount(run_dir, "/results", False),
        image, "/bin/bash", "/benchmark/run_evaluation.sh",
    ])
    logger.emit(
        "DEBUG", "container", "command.started",
        "Starting isolated evaluation container", command=command,
        container_name=container_name,
    )
    try:
        completed = subprocess.run(
            command, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            timeout=args.timeout,
        )
        completed_stdout = decode_output(completed.stdout)
        completed_stderr = decode_output(completed.stderr)
        container_exit_code = completed.returncode
    except subprocess.TimeoutExpired as error:
        timed_out = True
        completed_stdout = decode_output(error.stdout)
        completed_stderr = decode_output(error.stderr)
        subprocess.run(
            [args.docker, "rm", "-f", container_name],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        logger.emit(
            "ERROR", "container", "command.timeout",
            "Evaluation container exceeded the timeout",
            timeout_seconds=args.timeout,
        )

    write_text(run_dir / "docker-run.stdout.raw.log", completed_stdout)
    write_text(run_dir / "docker-run.stderr.raw.log", completed_stderr)
    phase_path = run_dir / "phase.json"
    if timed_out:
        phase = {
            "phase": "container", "outcome": "infrastructure_error",
            "reason": "evaluation_timeout", "test_exit_code": None,
            "instance_id": instance.get("instance_id"),
        }
    elif phase_path.is_file():
        phase = load_json(phase_path)
        phase["instance_id"] = instance.get("instance_id")
    else:
        logger.emit(
            "ERROR", "container", "phase.missing",
            "Container did not produce phase metadata",
            container_exit_code=container_exit_code,
        )
        phase = {
            "phase": "container", "outcome": "infrastructure_error",
            "reason": "phase_file_missing", "test_exit_code": None,
            "instance_id": instance.get("instance_id"),
        }

    tests_path = run_dir / "tests.raw.log"
    test_text = tests_path.read_text(encoding="utf-8", errors="replace") if tests_path.is_file() else ""
    observed = parse_test_log(test_text)
    fail_to_pass = expected_report(instance.get("FAIL_TO_PASS", []), observed)
    pass_to_pass = expected_report(instance.get("PASS_TO_PASS", []), observed)
    unexpected_failures = sorted(
        test_id for test_id, status in observed.items()
        if status in ("FAILED", "ERROR")
    )
    detailed_grading = {
        "schema_version": SCHEMA_VERSION,
        "run_id": run_id,
        "tests_observed": len(observed),
        "FAIL_TO_PASS": fail_to_pass,
        "PASS_TO_PASS": pass_to_pass,
        "unexpected_failures": unexpected_failures,
    }
    write_json(run_dir / "grading.json", detailed_grading)
    grading_summary = {
        "tests_observed": len(observed),
        "FAIL_TO_PASS": compact_counts(fail_to_pass),
        "PASS_TO_PASS": compact_counts(pass_to_pass),
        "unexpected_failures": len(unexpected_failures),
    }

    expected_ok = all(
        status == "PASSED"
        for status in list(fail_to_pass.values()) + list(pass_to_pass.values())
    )
    suite_ok = phase.get("test_exit_code") == 0 and not unexpected_failures
    resolved = (
        phase.get("phase") == "tests_complete"
        and phase.get("outcome") == "completed"
        and expected_ok and suite_ok
    )
    if phase.get("outcome") == "infrastructure_error":
        status = "error"
        reason = phase.get("reason", "infrastructure_error")
        exit_code = 2
    elif resolved:
        status = "resolved"
        reason = "all_expected_tests_passed"
        exit_code = 0
    elif phase.get("phase") != "tests_complete":
        status = "unresolved"
        reason = phase.get("reason", "evaluation_did_not_reach_tests")
        exit_code = 1
    elif not expected_ok:
        status = "unresolved"
        reason = "expected_test_failed_skipped_or_missing"
        exit_code = 1
    else:
        status = "unresolved"
        reason = "test_suite_failed"
        exit_code = 1

    return finish(status, reason, phase, grading_summary, exit_code)


if __name__ == "__main__":
    sys.exit(main())
