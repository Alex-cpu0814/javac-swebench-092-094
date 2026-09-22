# Case 094 evaluator

Case 094 uses the common case-092 v3 evaluator contract: a clean CentOS 7
checkout at the Base commit, with the candidate patch and protected
`patches/test_patch.diff` mounted only at runtime.

```powershell
docker pull yutu0814/javac-case-094-jep:benchmark-v3
python evaluator/evaluate_model_patch.py --patch C:\path\to\model_patch.diff
```

The image contains the 092-compatible Ubuntu/CPython 3.5.3 toolchain,
OpenJDK 8, and no gold or test patch. Build/audit artifacts are
stored in `verification/builds/`; evaluation artifacts are stored in
`verification/runs/`.
