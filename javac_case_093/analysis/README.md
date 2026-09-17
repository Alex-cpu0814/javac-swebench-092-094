# Case 93

This directory contains the working materials and Docker verification inputs
for source row 93. The final SWE-bench-compatible record is generated under
`official_swebench`.

## Source mapping

- Source row: `93`
- Repository: `ninia/jep`
- Issue: `#79`
- Issue URL: `https://github.com/ninia/jep/issues/79`
- Project version at Base: `3.6.3`
- Base commit: `9eeb14c4c8b2d0e49feece90a6e330826b49c7dd`
- Fix commit: `d14567567ac1281e978790b9170c981113de282f`
- Issue created: `2017-05-24`
- Fix commit date: `2017-05-30`
- Bug function: `pyembed_version_unsafe`
- Bug line: `264`

## Bug summary

The Base revision allocates exactly `strlen(pyversion)` bytes and then copies
the terminating null byte with `strcpy`. This writes one byte past the
allocation during JEP startup. The Fix revision allocates
`strlen(pyversion) + 1` bytes.

## Test decision

No upstream regression test for Issue #79 was found in the Base revision.
`test_patch.diff` therefore adds a focused synthetic test. It rebuilds the
native extension with GCC AddressSanitizer and starts a minimal Java/JEP
program. The sanitizer should fail on Base and pass on Fix.

The Linux Docker environment verified the intended behavior:

- Base: the synthetic regression test fails with an AddressSanitizer
  heap-buffer-overflow.
- Fix: `Ran 151 tests in 8.275s`, `OK (skipped=20)`.

The official record uses 130 `PASS_TO_PASS` tests, one
`FAIL_TO_PASS` test, and records the 20 skipped tests in `metadata.json`.
