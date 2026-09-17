# Case 093 model-patch evaluator

Build from this case directory with:

```powershell
Set-Location <case-directory>
.\evaluatoruild_model_evaluator.ps1
```

Evaluate a patch with:

```powershell
.\evaluator\evaluate_model_patch.ps1 `
  -PatchPath .\evaluator\model_patch.example.diff
```

The evaluator image contains only the Base archive, the regression test patch,
and the evaluator. It does not contain the Fix archive or the gold patch.
Results and logs are written under `verification/evaluator/`.
