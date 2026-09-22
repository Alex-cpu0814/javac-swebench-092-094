#!/usr/bin/env python3
"""Build and audit a configured benchmark evaluator image."""

from __future__ import print_function

import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
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


def inspect_image(docker, image):
    output = decode_output(subprocess.check_output(
        [docker, "image", "inspect", image]
    ))
    item = json.loads(output)[0]
    return {
        "name": image,
        "id": item.get("Id"),
        "repo_digests": item.get("RepoDigests") or [],
    }


def load_config(path):
    with path.open("r", encoding="utf-8") as handle:
        config = json.load(handle)
    required = (
        "case_number", "instance_id", "instance_file", "repo_url",
        "base_commit", "fix_commit", "image", "python_version",
        "python_sha256", "extra_apt_packages", "runtime_assets",
    )
    missing = [key for key in required if key not in config]
    if missing:
        raise SystemExit("Missing case config keys: {}".format(", ".join(missing)))
    return config


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--image")
    parser.add_argument("--repo-url")
    parser.add_argument("--docker", default="docker")
    parser.add_argument("--pull", action="store_true")
    parser.add_argument("--build-id")
    parser.add_argument("--timeout", type=int, default=1800)
    parser.add_argument(
        "--log-level", choices=("DEBUG", "INFO", "WARN", "ERROR"),
        default="INFO",
    )
    args = parser.parse_args(argv)

    if args.timeout <= 0:
        raise SystemExit("Timeout must be greater than zero")

    evaluator_dir = Path(__file__).resolve().parent
    case_dir = evaluator_dir.parent
    config = load_config(evaluator_dir / "case_config.json")
    image = args.image or config["image"]
    repo_url = args.repo_url or config["repo_url"]
    base_commit = config["base_commit"]
    fix_commit = config["fix_commit"]

    build_id = args.build_id or new_identifier("build")
    if not SAFE_ID.match(build_id):
        raise SystemExit("Invalid build id: {}".format(build_id))

    context_dir = evaluator_dir / "image"
    builds_dir = case_dir / "verification" / "builds"
    build_dir = builds_dir / build_id
    try:
        build_dir.mkdir(parents=True, exist_ok=False)
    except FileExistsError:
        raise SystemExit("Build directory already exists: {}".format(build_dir))

    events_path = build_dir / "events.jsonl"
    logger = EventLogger(events_path, build_id, args.log_level)
    started_at = utc_now()
    started_clock = time.monotonic()
    image_info = {"name": image, "id": None, "repo_digests": []}

    def finish(status, reason, exit_code):
        finished_at = utc_now()
        duration_ms = int((time.monotonic() - started_clock) * 1000)
        logger.emit(
            "INFO" if exit_code == 0 else "ERROR",
            "build", "build.completed",
            "Image build finished with status {}".format(status),
            status=status, reason=reason, exit_code=exit_code,
            duration_ms=duration_ms,
        )
        summary = {
            "schema_version": SCHEMA_VERSION,
            "kind": "image_build",
            "build_id": build_id,
            "status": status,
            "reason": reason,
            "started_at": started_at,
            "finished_at": finished_at,
            "duration_ms": duration_ms,
            "source": {
                "repo": repo_url,
                "base_commit": base_commit,
            },
            "image": image_info,
            "logs": {
                "events": "events.jsonl",
                "docker_build_stdout": (
                    "docker-build.stdout.raw.log"
                    if (build_dir / "docker-build.stdout.raw.log").is_file() else None
                ),
                "docker_build_stderr": (
                    "docker-build.stderr.raw.log"
                    if (build_dir / "docker-build.stderr.raw.log").is_file() else None
                ),
                "image_audit_stdout": (
                    "image-audit.stdout.raw.log"
                    if (build_dir / "image-audit.stdout.raw.log").is_file() else None
                ),
                "image_audit_stderr": (
                    "image-audit.stderr.raw.log"
                    if (build_dir / "image-audit.stderr.raw.log").is_file() else None
                ),
                "image_audit": (
                    "image-audit.json"
                    if (build_dir / "image-audit.json").is_file() else None
                ),
            },
        }
        write_json(build_dir / "summary.json", summary)
        write_json(builds_dir / "latest.json", {
            "schema_version": SCHEMA_VERSION,
            "build_id": build_id,
            "summary": "{}/summary.json".format(build_id),
        })
        return exit_code

    logger.emit(
        "INFO", "preflight", "build.started", "Starting evaluator image build",
        image=image, repo=repo_url, base_commit=base_commit,
        instance_id=config["instance_id"],
    )
    if shutil.which(args.docker) is None:
        logger.emit(
            "ERROR", "preflight", "docker.missing",
            "Docker executable was not found", executable=args.docker,
        )
        return finish("error", "docker_not_found", 2)

    dockerfile = context_dir / "Dockerfile"
    if not dockerfile.is_file():
        logger.emit(
            "ERROR", "preflight", "dockerfile.missing",
            "Evaluator Dockerfile was not found",
        )
        return finish("error", "dockerfile_missing", 2)

    with tempfile.TemporaryDirectory(
            prefix="javac-case-{}-image-".format(config["case_number"])) as temp_name:
        staged_context = Path(temp_name)
        shutil.copy2(str(dockerfile), str(staged_context / "Dockerfile"))
        write_text(staged_context / ".dockerignore", "*\n!Dockerfile\n")
        command = [
            args.docker, "build", "--progress=plain", "-t", image,
            "--build-arg", "REPO_URL={}".format(repo_url),
            "--build-arg", "BASE_COMMIT={}".format(base_commit),
            "--build-arg", "INSTANCE_ID={}".format(config["instance_id"]),
            "--build-arg", "PYTHON_VERSION={}".format(config["python_version"]),
            "--build-arg", "PYTHON_SHA256={}".format(config["python_sha256"]),
            "--build-arg", "EXTRA_APT_PACKAGES={}".format(
                " ".join(config["extra_apt_packages"])
            ),
        ]
        if args.pull:
            command.append("--pull")
        command.append(str(staged_context))
        logger.emit(
            "DEBUG", "docker_build", "command.started",
            "Executing Docker image build", command=command,
        )
        phase_clock = time.monotonic()
        build_stdout_path = build_dir / "docker-build.stdout.raw.log"
        build_stderr_path = build_dir / "docker-build.stderr.raw.log"
        with build_stdout_path.open("wb") as stdout_handle, \
                build_stderr_path.open("wb") as stderr_handle:
            process = subprocess.Popen(
                command, stdout=stdout_handle, stderr=stderr_handle,
            )
            try:
                build_returncode = process.wait(timeout=args.timeout)
            except subprocess.TimeoutExpired:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
                logger.emit(
                    "ERROR", "docker_build", "command.timeout",
                    "Docker image build exceeded the timeout",
                    timeout_seconds=args.timeout,
                )
                return finish("error", "docker_build_timeout", 2)
            except KeyboardInterrupt:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
                logger.emit(
                    "ERROR", "docker_build", "command.interrupted",
                    "Docker image build was interrupted",
                )
                return finish("error", "docker_build_interrupted", 2)
        build_duration_ms = int((time.monotonic() - phase_clock) * 1000)

    if build_returncode != 0:
        logger.emit(
            "ERROR", "docker_build", "command.failed",
            "Docker image build failed", exit_code=build_returncode,
            duration_ms=build_duration_ms,
        )
        return finish("error", "docker_build_failed", 2)
    logger.emit(
        "INFO", "docker_build", "command.completed",
        "Docker image build completed", duration_ms=build_duration_ms,
    )

    audit_script = """
set -euo pipefail
test -d /testbed/.git
test "$(git -C /testbed rev-parse HEAD)" = "{base}"
test -z "$(git -C /testbed status --porcelain)"
test ! -e /inputs/model.patch
test ! -e /inputs/test.patch
test ! -e /benchmark/run_evaluation.sh
test ! -e /benchmark/case_adapter.sh
if git -C /testbed cat-file -e "{fix}^{{commit}}" 2>/dev/null; then
  echo "fix commit leaked into image" >&2
  exit 1
fi
python --version
javac -version
""".format(base=base_commit, fix=fix_commit)
    logger.emit(
        "INFO", "image_audit", "audit.started", "Auditing clean evaluator image",
    )
    phase_clock = time.monotonic()
    audited = subprocess.run(
        [
            args.docker, "run", "--rm", "--network", "none",
            "--entrypoint", "/bin/bash", image, "-lc", audit_script,
        ],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )
    audit_duration_ms = int((time.monotonic() - phase_clock) * 1000)
    audited_stdout = decode_output(audited.stdout)
    audited_stderr = decode_output(audited.stderr)
    write_text(build_dir / "image-audit.stdout.raw.log", audited_stdout)
    write_text(build_dir / "image-audit.stderr.raw.log", audited_stderr)
    if audited.returncode != 0:
        logger.emit(
            "ERROR", "image_audit", "audit.failed",
            "Evaluator image audit failed", exit_code=audited.returncode,
            duration_ms=audit_duration_ms,
        )
        return finish("error", "image_audit_failed", 2)

    try:
        image_info.update(inspect_image(args.docker, image))
    except (subprocess.CalledProcessError, ValueError, KeyError, IndexError) as error:
        logger.emit(
            "ERROR", "image_audit", "inspect.failed",
            "Docker image inspection failed", detail=str(error),
        )
        return finish("error", "image_inspect_failed", 2)

    audit = {
        "schema_version": SCHEMA_VERSION,
        "instance_id": config["instance_id"],
        "base_commit": base_commit,
        "working_tree_clean": True,
        "fix_commit_present": False,
        "model_patch_present": False,
        "test_patch_present": False,
        "gold_patch_present": False,
        "evaluation_assets_injected_at_runtime": True,
        "network_disabled_during_audit": True,
    }
    write_json(build_dir / "image-audit.json", audit)
    logger.emit(
        "INFO", "image_audit", "audit.completed",
        "Evaluator image is clean", duration_ms=audit_duration_ms,
        image_id=image_info.get("id"),
    )
    return finish("success", "image_built_and_audited", 0)


if __name__ == "__main__":
    sys.exit(main())
