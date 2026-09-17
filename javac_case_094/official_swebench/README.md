# SWE-bench-compatible record: case 94

- Instance ID: `ninia__jep-40`
- Repository: `ninia/jep`
- Issue: `#40`
- Base: `bc2edaf0242736c2a2940104eebc6aed5a3ad9e6`
- Fix: `8144158fdaf3db44681e5eb4ef9a77907e4746b4`
- Project version: `3.5.0`

## Test provenance

The Base revision predates the later upstream regression test for Issue #40.
The test patch is therefore a dataset-construction test derived from the
later upstream test intent. It adds deterministic assertions for a Python
dictionary with a `None` key and a `None` value.

The provenance is recorded explicitly:

- `gold_patch.diff`: official upstream Fix commit.
- `test_patch.diff`: dataset-construction regression test derived from the
  later upstream Issue #40 test.
- `evaluator/model_patch.example.diff`: copy of the official gold patch for
  evaluator smoke testing only. It is not model-generated.

## Files

- `instance_094.json`: private record containing oracle fields.
- `instance_094.jsonl`: one-line private record.
- `public_task_094.json`: model-facing task without oracle fields.
- `metadata.json`: provenance and verification metadata.
- `evaluator`: model-patch evaluator.
- `analysis`: source and test decision notes.

The case is custom SWE-bench-compatible data, not an original row from the
official SWE-bench release.
