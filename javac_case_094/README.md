# Java-C to SWE-bench Case 094

Case 094 (`ninia__jep-40`) follows the common case-092 v3 layout.

- `analysis/`: environment and provenance notes.
- `patches/`: upstream fix and protected regression-test patch.
- `official_swebench/`: public task plus private instance metadata.
- `evaluator/`: config-driven runtime-injection evaluator and clean-image Dockerfile.
- `verification/`: immutable build and evaluation evidence.

The published image is `yutu0814/javac-case-094-jep:benchmark-v3`. It uses the
092-compatible Ubuntu/CPython 3.5.3 toolchain because the 094 Base otherwise
triggers the unrelated Issue 79 allocator defect before its own regression
test runs. The Fix passes the 96-test project suite.
