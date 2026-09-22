# Case 093 evaluator

Case 093 uses the common case-092 v3 evaluator contract: a clean CentOS 7
checkout at the Base commit, with the candidate patch and protected
`patches/test_patch.diff` mounted only at runtime.

```powershell
docker pull yutu0814/javac-case-093-jep:benchmark-v3
python evaluator/evaluate_model_patch.py --patch C:\path\to\model_patch.diff
```

The image contains CentOS 7, glibc 2.17, Anaconda 2.4.1/Python 3.5.1,
OpenJDK 8, GCC 4.8.5, and no gold or test patch. Build/audit artifacts are
stored in `verification/builds/`; evaluation artifacts are stored in
`verification/runs/`.
