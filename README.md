# Java-C SWE-bench-compatible cases

This repository contains three `ninia/jep` cross-language bug cases converted
to a SWE-bench-compatible record format.

| Case | Instance ID | Issue | FAIL_TO_PASS | PASS_TO_PASS | Evaluator generation |
|---|---|---:|---:|---:|---|
| 092 | `ninia__jep-77` | 77 | 1 | 121 | v3 single-image, runtime injection |
| 093 | `ninia__jep-79` | 79 | 1 | 130 | legacy release |
| 094 | `ninia__jep-40` | 40 | 1 | 95 | legacy release |

## Case 092

Case 092 is the current reference implementation. Its evaluator follows the
SWE-bench isolation pattern without requiring the official harness:

```text
clean Base image
  -> inject model patch at container runtime
  -> inject protected test patch at container runtime
  -> build
  -> run tests
  -> grade FAIL_TO_PASS and PASS_TO_PASS
```

The one Base image contains the historical toolchain and a pruned checkout at
the exact Base commit. It does not contain the model patch, protected test
patch, gold patch, Fix source, expected outcomes, or evaluation entrypoint.

Verified Docker Hub image:

```text
yutu0814/javac-case-092-jep:benchmark-v3
sha256:da9c9293093a89f2cfd0e2d584077080c640f0c002cef0589c64e28ac6b550d4
```

### Evaluate a candidate patch

Requirements: Git, Docker with Linux containers, and Python 3.5 or newer.

```powershell
git clone https://github.com/Alex-cpu0814/javac-swebench-092-094.git
Set-Location .\javac-swebench-092-094\javac_case_092

docker pull yutu0814/javac-case-092-jep:benchmark-v3

python .\evaluator\evaluate_model_patch.py `
  --patch C:\path\to\my_model_patch.diff
```

The default image is read from `evaluator/case_config.json`. Results are stored
under `verification/runs/<run-id>/`:

- `summary.json`: final `resolved`, `unresolved`, or `error` result.
- `grading.json`: per-test F2P/P2P results.
- `events.jsonl`: structured schema-3.0 event log.
- `*.raw.log`: unmodified patch, build, test, and Docker output.

Exit code `0` means resolved, `1` means the candidate is unresolved, and `2`
means evaluator/infrastructure error.

The included `patches/gold_patch.diff` is an upstream maintainer control, not
a model-generated answer. Do not use it when measuring model repair ability.

### Build the image locally (maintainers)

```powershell
Set-Location .\javac_case_092
.\evaluator\build_model_evaluator.ps1
```

The Docker build clones the upstream repository and checks out the Base commit,
so local image construction requires network access. Normal users only need the
published image.

## Cases 093 and 094

Cases 093 and 094 retain the earlier two-image/public-release structure for
now. Their Docker Hub tags and usage instructions remain inside each case
directory. They have not yet been migrated to the case-092 v3 template.

## Records and provenance

Each case includes SWE-bench-compatible records under `official_swebench/`:

```text
instance_NNN.json
instance_NNN.jsonl
public_task_NNN.json
metadata.json
```

`public_task_*.json` is the model-facing task. The complete instance and the
private evaluator materials include oracle information and should not be shown
to a model during an unbiased evaluation. Patch provenance and verification
details are recorded in each case's `metadata.json`.

## Links

- GitHub: [Alex-cpu0814/javac-swebench-092-094](https://github.com/Alex-cpu0814/javac-swebench-092-094)
- Docker Hub: [yutu0814](https://hub.docker.com/u/yutu0814)

The original source and patches remain subject to the upstream `ninia/jep`
license.
