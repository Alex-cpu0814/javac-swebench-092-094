#!/usr/bin/env bash
set -euo pipefail

ROOT=/opt/javac_case_093
BASE_DIR=${ROOT}/work/base
FIX_DIR=${ROOT}/work/fix
LOG_DIR=${ROOT}/logs

rm -rf "${ROOT}/work" "${LOG_DIR}"
mkdir -p "${BASE_DIR}" "${FIX_DIR}" "${LOG_DIR}"

tar -xzf "${ROOT}/jep_base_9eeb14c.tar.gz" -C "${BASE_DIR}"
tar -xzf "${ROOT}/jep_fix_d145675.tar.gz" -C "${FIX_DIR}"

echo "== Environment =="
python --version
javac -version
java -version
gcc --version | head -n 1
gcc -print-file-name=libasan.so

run_revision() {
    local name="$1"
    local dir="$2"
    local log="${LOG_DIR}/${name}.log"

    echo "== ${name}: apply regression test and run suite =="
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
fix_success=false

if grep -q "test_version_unsafe" "${LOG_DIR}/base.log" \
    && grep -q "AddressSanitizer" "${LOG_DIR}/base.log" \
    && grep -Eq 'FAILED|ERROR' "${LOG_DIR}/base.log"; then
    base_failure=true
fi

if [[ "${fix_status}" -eq 0 ]] \
    && grep -q "Ran 151 tests" "${LOG_DIR}/fix.log" \
    && grep -Eq '^OK( \(skipped=[0-9]+\))?$' "${LOG_DIR}/fix.log"; then
    fix_success=true
fi

cat > "${LOG_DIR}/summary.json" <<EOF
{
  "instance_id": "ninia__jep-79",
  "base_command_exit_code": ${base_status},
  "fix_command_exit_code": ${fix_status},
  "base_failure_detected": ${base_failure},
  "fix_success_detected": ${fix_success},
  "fail_to_pass": ["test_version_unsafe.TestVersionUnsafe.test_version_unsafe"],
  "command": "python setup.py test"
}
EOF

cat "${LOG_DIR}/summary.json"

if [[ "${base_failure}" != "true" ]]; then
    echo "Base run did not show the expected ASan regression." >&2
    exit 1
fi

if [[ "${fix_success}" != "true" ]]; then
    echo "Fix run did not pass the ASan regression test and full suite." >&2
    exit 1
fi

echo "SWE-bench-style validation passed: base fails and fix passes."
