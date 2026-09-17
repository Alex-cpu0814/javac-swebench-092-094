#!/usr/bin/env bash
set -euo pipefail

ROOT=/opt/javac_case_094
BASE_DIR=${ROOT}/work/base
FIX_DIR=${ROOT}/work/fix
LOG_DIR=${ROOT}/logs

rm -rf "${ROOT}/work" "${LOG_DIR}"
mkdir -p "${BASE_DIR}" "${FIX_DIR}" "${LOG_DIR}"

tar -xzf "${ROOT}/jep_base_bc2edaf.tar.gz" -C "${BASE_DIR}"
tar -xzf "${ROOT}/jep_fix_8144158.tar.gz" -C "${FIX_DIR}"

echo "== Environment =="
python --version
javac -version
java -version
gcc --version | head -n 1

run_revision() {
    local name="$1"
    local dir="$2"
    local build_log="${LOG_DIR}/${name}_build.log"
    local test_log="${LOG_DIR}/${name}_tests.log"
    local log="${LOG_DIR}/${name}.log"
    echo "== ${name}: apply test patch, build, and run suite =="
    while IFS= read -r -d '' source_file; do
        sed -i 's/\r$//' "${source_file}"
    done < <(find "${dir}" -type f \( \
        -name '*.c' -o -name '*.h' -o -name '*.java' -o -name '*.py' \
        -o -name '*.txt' -o -name '*.rst' -o -name '*.xml' \
    \) -print0)
    cd "${dir}"
    git init -q
    git apply --whitespace=nowarn "${ROOT}/test_patch.diff"
    python setup.py clean >/dev/null 2>&1 || true
    unset LD_PRELOAD
    set +e
    python setup.py build >"${build_log}" 2>&1
    local build_status=$?
    set -e
    if [[ "${build_status}" -ne 0 ]]; then
        cat "${build_log}" >"${log}"
        echo "${build_status}" > "${LOG_DIR}/${name}.exit"
        return
    fi

    local native_lib native_dir
    native_lib="$(find build -type f -name 'jep*.so' -print -quit)"
    if [[ -z "${native_lib}" ]]; then
        echo "Could not locate the built JEP native library." >"${test_log}"
        cat "${build_log}" "${test_log}" >"${log}"
        echo "2" > "${LOG_DIR}/${name}.exit"
        return
    fi
    native_dir="$(dirname "${native_lib}")"
    # distutils names the extension jep.so, while System.loadLibrary("jep")
    # requires the conventional Linux name libjep.so.
    ln -sf "$(basename "${native_lib}")" "${native_dir}/libjep.so"

    export LD_LIBRARY_PATH="/opt/python-3.5.3/lib:${native_dir}:${LD_LIBRARY_PATH:-}"
    python_lib="$(find /opt/python-3.5.3/lib -maxdepth 1 -type f \
        \( -name 'libpython3.5m.so*' -o -name 'libpython3.5.so*' \) \
        | head -n 1)"
    if [[ -n "${python_lib}" ]]; then
        export LD_PRELOAD="${python_lib}${LD_PRELOAD:+:${LD_PRELOAD}}"
    fi

    set +e
    java -cp "build/java:build/java/test:tests/lib/sqlitejdbc-v056.jar" \
        -Djava.library.path="${native_dir}" \
        jep.Run runtests.py 2>&1 | tee "${test_log}"
    local status=${PIPESTATUS[0]}
    set -e
    cat "${build_log}" "${test_log}" >"${log}"
    echo "${status}" > "${LOG_DIR}/${name}.exit"
}

run_revision base "${BASE_DIR}"
run_revision fix "${FIX_DIR}"

base_status=$(cat "${LOG_DIR}/base.exit")
fix_status=$(cat "${LOG_DIR}/fix.exit")
base_failure=false
fix_success=false

if grep -q "test_none_dictionary" "${LOG_DIR}/base_tests.log" \
    && grep -Eq 'FAIL|ERROR|AssertionError|JepException' "${LOG_DIR}/base_tests.log"; then
    base_failure=true
fi

if [[ "${fix_status}" -eq 0 ]] \
    && grep -q "test_none_dictionary" "${LOG_DIR}/fix_tests.log" \
    && grep -Eq '^OK( \(skipped=[0-9]+\))?$' "${LOG_DIR}/fix_tests.log"; then
    fix_success=true
fi

cat > "${LOG_DIR}/summary.json" <<EOF
{
  "instance_id": "ninia__jep-40",
  "base_command_exit_code": ${base_status},
  "fix_command_exit_code": ${fix_status},
  "base_failure_detected": ${base_failure},
  "fix_success_detected": ${fix_success},
  "fail_to_pass": ["test_none_dictionary.TestNoneDictionaryRegression.test_none_dictionary"],
  "command": "python setup.py build; java -cp build/java:build/java/test jep.Run runtests.py"
}
EOF
cat "${LOG_DIR}/summary.json"

if [[ "${base_failure}" != "true" ]]; then
    echo "Base run did not show the expected None dictionary failure." >&2
    exit 1
fi
if [[ "${fix_success}" != "true" ]]; then
    echo "Fix run did not pass the None dictionary regression and suite." >&2
    exit 1
fi
echo "SWE-bench-style validation passed: base fails and fix passes."
