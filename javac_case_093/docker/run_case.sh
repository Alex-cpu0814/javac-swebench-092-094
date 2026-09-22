#!/usr/bin/env bash
set -euo pipefail

ROOT=/opt/javac_case_093
BASE_DIR=${ROOT}/work/base
FIX_DIR=${ROOT}/work/fix
LOG_DIR=${LOG_DIR:-${ROOT}/logs}

rm -rf "${ROOT}/work"
mkdir -p "${BASE_DIR}" "${FIX_DIR}" "${LOG_DIR}"

tar -xzf "${ROOT}/jep_base_9eeb14c.tar.gz" -C "${BASE_DIR}"
tar -xzf "${ROOT}/jep_fix_d145675.tar.gz" -C "${FIX_DIR}"

{
    echo "== Environment =="
    cat /etc/centos-release
    python --version 2>&1
    python -c "import ctypes; f=ctypes.pythonapi.Py_GetVersion; f.restype=ctypes.c_char_p; print(repr(f())); print('Py_GetVersion_length=' + str(len(f())))"
    javac -version 2>&1
    java -version 2>&1
    gcc --version 2>&1
    ldd --version 2>&1
} | tee "${LOG_DIR}/environment.log"

run_revision() {
    local name="$1"
    local dir="$2"
    local log="${LOG_DIR}/${name}.log"

    echo "== ${name}: project-native setup.py test =="
    cd "${dir}"
    git init -q
    git apply --whitespace=nowarn "${ROOT}/test_patch.diff"
    python setup.py clean >/dev/null 2>&1 || true
    set +e
    python setup.py test 2>&1 | tee "${log}"
    local status=${PIPESTATUS[0]}
    set -e
    echo "${status}" > "${LOG_DIR}/${name}.exit"
}

run_revision "base" "${BASE_DIR}"
run_revision "fix" "${FIX_DIR}"

base_status="$(cat "${LOG_DIR}/base.exit")"
fix_status="$(cat "${LOG_DIR}/fix.exit")"
base_failure=false
author_exact_diagnostic=false
allocator_corruption_equivalent=false
fix_success=false

if grep -q "pyembed_startup" "${LOG_DIR}/base.log" \
    && grep -Eq 'free\(\): invalid next size|corrupted size vs\. prev_size|sysmalloc: Assertion' "${LOG_DIR}/base.log"; then
    base_failure=true
    if grep -q "free(): invalid next size" "${LOG_DIR}/base.log"; then
        author_exact_diagnostic=true
    else
        allocator_corruption_equivalent=true
    fi
fi

if [[ "${fix_status}" -eq 0 ]] \
    && grep -q "Ran 151 tests" "${LOG_DIR}/fix.log" \
    && grep -Eq '^OK( \(skipped=[0-9]+\))?$' "${LOG_DIR}/fix.log"; then
    fix_success=true
fi

cat > "${LOG_DIR}/summary.json" <<EOF
{
  "instance_id": "ninia__jep-79",
  "mode": "historical_centos7_project_native_test_style",
  "base_image": "centos:7",
  "glibc": "2.17",
  "python_distribution": "Anaconda3-2.4.1",
  "base_command_exit_code": ${base_status},
  "fix_command_exit_code": ${fix_status},
  "base_failure_detected": ${base_failure},
  "author_exact_diagnostic": ${author_exact_diagnostic},
  "allocator_corruption_equivalent": ${allocator_corruption_equivalent},
  "fix_success_detected": ${fix_success},
  "test_framework": "python setup.py test -> jep.Run -> unittest discover",
  "test_command": "python setup.py test"
}
EOF

cat "${LOG_DIR}/summary.json"

if [[ "${base_failure}" != "true" ]]; then
    echo "Base did not show the expected allocator corruption." >&2
    exit 1
fi

if [[ "${fix_success}" != "true" ]]; then
    echo "Fix did not pass the project-native test suite." >&2
    exit 1
fi

echo "Project-native historical validation passed: Base fails and Fix passes."
