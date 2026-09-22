# Case 092 isolated model-patch evaluator

The evaluator follows SWE-bench's isolation pattern without depending on the
official harness. Common isolation, patching, grading, and logging behavior is
kept separate from the two case-specific files:

- `case_config.json`: identity, commits, image tag, dependencies, and mounts.
- `case_adapter.sh`: `build_project` and `run_project_tests` functions.

The image contains only the historical toolchain and a clean Git checkout at
the Base commit. It contains no model patch, test patch, gold patch, Fix source,
expected test outcomes, or evaluation entrypoint.

For normal use, pull the verified image published on Docker Hub:

```powershell
docker pull yutu0814/javac-case-092-jep:benchmark-v3
```

Its published digest is
`sha256:da9c9293093a89f2cfd0e2d584077080c640f0c002cef0589c64e28ac6b550d4`.
The evaluator uses this image by default.

Maintainers can instead build and audit the clean image locally:

```powershell
Set-Location <case-directory>
.\evaluator\build_model_evaluator.ps1
```

Evaluate a patch with:

```powershell
.\evaluator\evaluate_model_patch.ps1 `
  -PatchPath <candidate-patch.diff>
```

Cross-platform entry points are also available:

```text
python evaluator/build_model_evaluator.py
python evaluator/evaluate_model_patch.py --patch my_model_patch.diff
```

At runtime the host mounts the candidate patch, protected `test_patch`, case
adapter, test runner, and writable result directory. The order is:

```text
clean Base -> model patch -> test patch -> build -> tests -> grade
```

The grader requires every `FAIL_TO_PASS` and `PASS_TO_PASS` test to be observed
as `PASSED`. Missing and skipped target tests fail the evaluation. Every build
and run receives an immutable identifier:

```text
verification/builds/<build_id>/
verification/runs/<run_id>/
```

`summary.json` is compact, `grading.json` contains per-test details,
`events.jsonl` contains the structured timeline, and `*.raw.log` files preserve
tool output. Severity describes evaluator health: an unresolved candidate is a
normal `WARN`, while infrastructure or harness failure is `ERROR`. See
`LOGGING.md` for schema 3.0.

`image/` is a deliberately minimal Docker build context containing one
Dockerfile. The build clones `ninia/jep`, checks out the exact Base commit, then
removes upstream refs and unreachable objects. Building therefore requires
network access; no source archive or Git bundle is embedded in the context.
