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
    cat /etc/os-release
    python --version 2>&1
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
asan_failure_detected=false
fix_success=false

if grep -q "AddressSanitizer" "${LOG_DIR}/base.log" \
    && grep -q "heap-buffer-overflow" "${LOG_DIR}/base.log" \
    && grep -q "pyembed_version_unsafe" "${LOG_DIR}/base.log"; then
    base_failure=true
    asan_failure_detected=true
fi

if [[ "${fix_status}" -eq 0 ]] \
    && grep -q "Ran 151 tests" "${LOG_DIR}/fix.log" \
    && grep -Eq '^OK( \(skipped=[0-9]+\))?$' "${LOG_DIR}/fix.log"; then
    fix_success=true
fi

cat > "${LOG_DIR}/summary.json" <<EOF
{
  "instance_id": "ninia__jep-79",
  "mode": "swebench_ubuntu_asan_project_native_test_style",
  "base_image": "eclipse-temurin:8-jdk-jammy",
  "python_distribution": "Python-${PYTHON_VERSION:-3.5.3}",
  "base_command_exit_code": ${base_status},
  "fix_command_exit_code": ${fix_status},
  "base_failure_detected": ${base_failure},
  "asan_failure_detected": ${asan_failure_detected},
  "fix_success_detected": ${fix_success},
  "test_framework": "python setup.py test -> jep.Run -> unittest discover",
  "test_command": "python setup.py test"
}
EOF

cat "${LOG_DIR}/summary.json"

if [[ "${base_failure}" != "true" ]]; then
    echo "Base did not show the expected ASan regression." >&2
    exit 1
fi

if [[ "${fix_success}" != "true" ]]; then
    echo "Fix did not pass the project-native test suite." >&2
    exit 1
fi

echo "Project-native historical validation passed: Base fails and Fix passes."
