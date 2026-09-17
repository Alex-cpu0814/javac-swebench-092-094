# Case 093 model-patch evaluator

The evaluator image is prebuilt and published on Docker Hub:

yutu0814/javac-case-093-jep:model-evaluator

From the repository root, run:

python tools/evaluate_model_patch.py --case-dir javac_case_093 --image yutu0814/javac-case-093-jep:model-evaluator --patch ./my_model_patch.diff --pull

The result is written to:

javac_case_093/verification/evaluator/model_patch_summary.json

The image contains the Base source, regression test, and evaluator. It does not contain the Fix archive or the gold patch.