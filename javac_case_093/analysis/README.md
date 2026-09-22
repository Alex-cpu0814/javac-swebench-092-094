# Case 093 analysis

The official Issue 79 fix changes the allocation in `pyembed_version_unsafe`
to include the terminating byte. The Base regression test is the protected
`TestVersionUnsafe` test in `patches/test_patch.diff`. CentOS 7 is retained
because its glibc allocator reliably reports the Base heap corruption while
the fixed revision completes the native project suite.
