# Java-C to SWE-bench Case 093

This directory follows the common Java-C to SWE-bench-compatible case layout.

## Identity

- Instance ID: `ninia__jep-79`
- Case number: `093`
- Repository, issue, commits, and project version: `official_swebench/metadata.json`

## Directory contract

- `analysis/`: source-row mapping, provenance, and case analysis.
- `source/`: Base and Fix source archives, stored once.
- `patches/`: upstream gold patch and the exact regression-test patch.
- `official_swebench/`: private/public records and metadata.
- Docker Hub image: `yutu0814/javac-case-093-jep:swebench-ubuntu-asan` (prebuilt; see the repository README).
- `evaluator/`: model-patch evaluator without the Fix archive or gold patch.
- `verification/`: Docker and evaluator logs/results.

## Verification

The expected relationship is:

```text
Base fails the regression test
Fix passes the regression test and the runnable suite
```

The evaluator smoke test uses `evaluator/model_patch.example.diff`, which is
a known-correct patch for pipeline validation, not a model-generated result.
