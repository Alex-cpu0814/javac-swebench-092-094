# Evaluator logging schema 3.0

Builds and evaluations are immutable operations with independent identifiers.
Image-build artifacts are written to `verification/builds/<build_id>/`; patch
evaluation artifacts are written to `verification/runs/<run_id>/`.

`events.jsonl` is the structured timeline. Every line is a JSON object with
`schema_version`, UTC `timestamp`, `level`, `operation_id`, `phase`, `event`,
and `message`. Event-specific fields such as exit code and duration may follow.

Levels describe evaluator health, not whether a candidate solves the task:

- `DEBUG`: commands and low-level diagnostics.
- `INFO`: normal phase transitions and final grading outcomes.
- `WARN`: candidate-caused rejection, missing observations, or other expected
  non-success outcomes.
- `ERROR`: Docker, image, protected-asset, timeout, or harness failures.

Raw Docker, patch, compiler, and test output is never rewritten into artificial
levels. It is stored in separate `*.raw.log` files. `summary.json` is compact
and contains only relative artifact paths; detailed per-test results live in
`grading.json`.

Process exit codes are stable:

- `0`: candidate resolved the instance.
- `1`: candidate was evaluated but did not resolve the instance.
- `2`: build, infrastructure, timeout, or evaluator error.
