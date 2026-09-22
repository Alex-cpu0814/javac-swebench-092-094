# Java-C to SWE-bench Case 093

Case 093 (`ninia__jep-79`) follows the common case-092 v3 layout.

- `analysis/`: environment and provenance notes.
- `patches/`: upstream fix and protected regression-test patch.
- `official_swebench/`: public task plus private instance metadata.
- `evaluator/`: config-driven runtime-injection evaluator and clean-image Dockerfile.
- `verification/`: immutable build and evaluation evidence.

The published image is `yutu0814/javac-case-093-jep:benchmark-v3`. It uses the
verified CentOS 7 allocator environment because this case's Base regression is
allocator corruption; the Base emits an allocator diagnostic and the Fix passes
the 151-test project suite.
