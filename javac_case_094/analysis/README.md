# Case 94 Analysis

## Source mapping

- Source row: `94`
- Repository: `ninia/jep`
- Issue: `#40`
- Issue URL: https://github.com/ninia/jep/issues/40
- Base: `bc2edaf0242736c2a2940104eebc6aed5a3ad9e6`
- Fix: `8144158fdaf3db44681e5eb4ef9a77907e4746b4`
- Base project version: `3.5.0`

## Bug and fix

`pyembed_box_py()` converts Python objects to Java objects. Python `None` is
represented by a Java `null`, so returning `NULL` is valid for a dictionary
key or value. The Base implementation treated every `NULL` return as an
error and therefore failed when a Python dictionary contained `None`. The
Fix checks `PyErr_Occurred()` before treating the `NULL` result as an error.

## Test provenance

The Base commit does not contain a regression test for Issue #40. The later
upstream commit `d46540ad97e94b30e236673e301ddef4e8434a23` added
`TestNoneDictionary.java`, but that test only printed the converted values and
did not make the test process fail on an incorrect result. The case therefore
adds a deterministic test based on that upstream test's intent. It asserts
that both a `None` value and a `None` key survive conversion to `HashMap`.

The Base checkout predates the later `tests/jep_pipe.py` and unittest
discovery structure, so the test patch registers the regression module in the
Base `tests/__init__.py` package and keeps the original root `runtests.py`
entry point.

This provenance is intentional:

- `gold_patch.diff`: official upstream Fix commit.
- `test_patch.diff`: dataset-construction test derived from later upstream
  Issue #40 test intent.
- `model_patch.example.diff`: copy of the official Fix for evaluator smoke
  testing only. It is not model-generated.

## Expected acceptance

The Base run must fail:

`test_none_dictionary.TestNoneDictionary.test_none_dictionary`

The Fix run must pass the regression and all runnable tests. The exact
`PASS_TO_PASS` list is generated only after the Base/Fix runs and is recorded
in `metadata.json` and the private instance record.
