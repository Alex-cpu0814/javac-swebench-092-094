# Java-C to SWE-bench Case 092

This directory follows the common Java-C to SWE-bench-compatible case layout.

## Identity

- Instance ID: `ninia__jep-77`
- Case number: `092`
- Repository, issue, commits, and project version: `official_swebench/metadata.json`

## Directory contract

- `analysis/`: source-row mapping, provenance, and case analysis.
- `patches/`: upstream gold patch and exact regression-test patch.
- `official_swebench/`: private/public records, metadata, and checksums.
- `evaluator/`: config-driven evaluator, case adapter, and one Dockerfile.
- `verification/`: final immutable build, runs, and control patches.

## Verification

The expected relationship is:

```text
Base fails the regression test
Fix passes the regression test and the runnable suite
```

The evaluator uses one image built from `evaluator/image/Dockerfile`. During
image construction it clones the upstream repository, checks out the Base
commit, removes upstream refs and unreachable objects, and audits that the Fix
commit is absent. `evaluator/case_config.json` contains case identity and
environment parameters; `evaluator/case_adapter.sh` contains only the JEP build
and test commands.

Candidate and protected test patches are mounted only after a fresh container
starts and are applied in that order. Structured log schema 3.0 separates image
builds under `verification/builds/` from patch runs under
`verification/runs/`; see `evaluator/LOGGING.md`.

The verified evaluator image is published on Docker Hub as
`yutu0814/javac-case-092-jep:benchmark-v3` (digest
`sha256:da9c9293093a89f2cfd0e2d584077080c640f0c002cef0589c64e28ac6b550d4`).

Legacy Base/Fix archives, the old oracle Docker context, duplicate answer
patch, and v1/v2 logs were removed from the final case directory after the v3
controls passed.
