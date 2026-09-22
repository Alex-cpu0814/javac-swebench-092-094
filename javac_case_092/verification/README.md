# Case 092 verification

Schema-3.0 verification separates image construction from candidate runs:

- `builds/<build_id>/`: structured build events, raw BuildKit output, image
  audit, and compact summary.
- `runs/<run_id>/`: structured runtime events, raw patch/build/test output,
  detailed grading, and compact summary.
- `controls/`: reusable negative and protected-test tampering patches.

The verified v3 image was built from the upstream GitHub repository at Base
commit `d14567567ac1281e978790b9170c981113de282f`. Its audit confirms a clean
working tree and no Fix commit, model patch, test patch, gold patch, or harness
assets.

Formal control runs:

| Run | Expected result |
|---|---|
| `case-092-final-gold` | resolved; F2P 1/1 and P2P 121/121 |
| `case-092-final-negative` | unresolved; regression remains failing |
| `case-092-final-tamper` | unresolved before tests; candidate conflicts with protected test patch |
| `case-092-final-py35-gold` | resolved through the host Python 3.5 entrypoint |

The final image build is `case-092-final-build`. Superseded v1/v2 logs and
intermediate v3 runs are not part of this case directory.
