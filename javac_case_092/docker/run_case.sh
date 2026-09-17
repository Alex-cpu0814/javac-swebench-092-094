#!/usr/bin/env bash
set -euo pipefail

ROOT=/opt/javac_case_092
BASE_DIR=${ROOT}/work/base
FIX_DIR=${ROOT}/work/fix
LOG_DIR=${ROOT}/logs

rm -rf "${ROOT}/work" "${LOG_DIR}"
mkdir -p "${BASE_DIR}" "${FIX_DIR}" "${LOG_DIR}"

tar -xzf "${ROOT}/jep_base_d145675.tar.gz" -C "${BASE_DIR}"
tar -xzf "${ROOT}/jep_fix_bd14a110.tar.gz" -C "${FIX_DIR}"

echo "== Environment =="
python --version
javac -version
java -version
gcc --version | head -n 1

echo "== Base: apply official regression tests =="
cd "${BASE_DIR}"
patch -p1 < "${ROOT}/test_patch.diff"
python setup.py clean >/dev/null 2>&1 || true
set +e
python setup.py test 2>&1 | tee "${LOG_DIR}/base.log"
base_status=${PIPESTATUS[0]}
set -e

echo "== Fix: run upstream fixed commit =="
cd "${FIX_DIR}"
python setup.py clean >/dev/null 2>&1 || true
set +e
python setup.py test 2>&1 | tee "${LOG_DIR}/fix.log"
fix_status=${PIPESTATUS[0]}
set -e

base_failure=false
fix_success=false

if grep -q "test_compiledScript" "${LOG_DIR}/base.log" && grep -q "Bad code object in .pyc file" "${LOG_DIR}/base.log"; then
    base_failure=true
fi

if [[ "${fix_status}" -eq 0 ]] \
    && grep -q "Ran 151 tests" "${LOG_DIR}/fix.log" \
    && grep -Eq '^OK( \(skipped=[0-9]+\))?$' "${LOG_DIR}/fix.log"; then
    fix_success=true
fi

cat > "${LOG_DIR}/summary.json" <<EOF
{
  "instance_id": "javac__ninia_jep__bd14a110__line1332__pyembed_run_pyc__case92",
  "base_command_exit_code": ${base_status},
  "fix_command_exit_code": ${fix_status},
  "base_failure_detected": ${base_failure},
  "fix_success_detected": ${fix_success},
  "fail_to_pass": ["test_run_script.TestRunScript.test_compiledScript"],
  "command": "python setup.py test"
}
EOF

cat "${LOG_DIR}/summary.json"

if [[ "${base_failure}" != "true" ]]; then
    echo "Base run did not show the expected compiled-script failure." >&2
    exit 1
fi

if [[ "${fix_success}" != "true" ]]; then
    echo "Fix run did not show the expected all-tests-passing result." >&2
    exit 1
fi

echo "SWE-bench-style validation passed: base fails and fix passes."
