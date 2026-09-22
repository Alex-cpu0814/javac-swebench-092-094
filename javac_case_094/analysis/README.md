# Case 094 analysis

The Issue 40 fix preserves Java `null` for Python `None` keys and values by
checking `PyErr_Occurred()` instead of treating every null JNI reference as an
exception. The protected regression test is applied at runtime from
`patches/test_patch.diff`; the clean image contains only the Base checkout and
historical CentOS 7 toolchain.
