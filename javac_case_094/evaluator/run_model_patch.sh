#!/usr/bin/env bash
set -uo pipefail

ROOT=/opt/javac_case_094
BASE_DIR="${ROOT}/work/model"
PATCH_PATH="${MODEL_PATCH_PATH:-${ROOT}/model_patch.diff}"
RESULT_DIR="${RESULT_DIR:-${ROOT}/logs/model_patch}"
LOG_DIR="${RESULT_DIR}/logs"
RESULT_PATH="${RESULT_PATH:-${RESULT_DIR}/summary.json}"

mkdir -p "${LOG_DIR}"
rm -rf "${BASE_DIR}"
mkdir -p "${BASE_DIR}"

write_result() {
    local status="$1"
    local reason="$2"
    local test_status="${3:-null}"
    local patch_sha256="${4:-}"
    mkdir -p "$(dirname "${RESULT_PATH}")"
    cat > "${RESULT_PATH}" <<EOF
{
  "instance_id": "ninia__jep-40",
  "status": "${status}",
  "reason": "${reason}",
  "test_command": "python setup.py build; java -cp build/java:build/java/test jep.Run runtests.py",
  "test_exit_code": ${test_status},
  "model_patch": "${PATCH_PATH}",
  "model_patch_sha256": "${patch_sha256}",
  "logs": "${LOG_DIR}",
  "fail_to_pass": ["test_none_dictionary.TestNoneDictionaryRegression.test_none_dictionary"],
  "pass_to_pass_count": 95
}
EOF
    cat "${RESULT_PATH}"
}

if [[ ! -f "${PATCH_PATH}" ]]; then
    write_result "failed" "model_patch_missing"
    exit 2
fi

patch_sha256="$(sha256sum "${PATCH_PATH}" | awk '{print $1}')"

if ! tar -xzf "${ROOT}/jep_base_bc2edaf.tar.gz" -C "${BASE_DIR}"; then
    write_result "failed" "base_archive_extract_failed" null "${patch_sha256}"
    exit 2
fi

while IFS= read -r -d '' source_file; do
    sed -i 's/\r$//' "${source_file}"
done < <(find "${BASE_DIR}" -type f \( \
    -name '*.c' -o -name '*.h' -o -name '*.java' -o -name '*.py' \
    -o -name '*.txt' -o -name '*.rst' -o -name '*.xml' \
\) -print0)

cd "${BASE_DIR}" || {
    write_result "failed" "base_directory_unavailable" null "${patch_sha256}"
    exit 2
}

git init -q

if ! git apply --check --whitespace=nowarn "${ROOT}/test_patch.diff" \
    > "${LOG_DIR}/test_patch.log" 2>&1 \
    || ! git apply --whitespace=nowarn "${ROOT}/test_patch.diff" \
    >> "${LOG_DIR}/test_patch.log" 2>&1; then
    write_result "failed" "test_patch_apply_failed" null "${patch_sha256}"
    exit 2
fi

if ! git apply --check --whitespace=nowarn "${PATCH_PATH}" \
    > "${LOG_DIR}/model_patch.log" 2>&1 \
    || ! git apply --whitespace=nowarn "${PATCH_PATH}" \
    >> "${LOG_DIR}/model_patch.log" 2>&1; then
    write_result "failed" "model_patch_apply_failed" null "${patch_sha256}"
    exit 2
fi

python setup.py clean > /dev/null 2>&1 || true
unset LD_PRELOAD
if ! python setup.py build > "${LOG_DIR}/build.log" 2>&1; then
    write_result "failed" "build_failed" null "${patch_sha256}"
    exit 1
fi

native_lib="$(find build -type f -name 'jep*.so' -print -quit)"
if [[ -z "${native_lib}" ]]; then
    write_result "failed" "native_library_not_found" null "${patch_sha256}"
    exit 1
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
    jep.Run runtests.py 2>&1 | tee "${LOG_DIR}/tests.log"
test_status=${PIPESTATUS[0]}
set -e

if [[ "${test_status}" -eq 0 ]] \
    && grep -Eq '^OK( \(skipped=[0-9]+\))?$' "${LOG_DIR}/tests.log" \
    && ! grep -q '^FAILED' "${LOG_DIR}/tests.log"; then
    write_result "resolved" "all_tests_passed" "${test_status}" "${patch_sha256}"
    exit 0
fi

write_result "failed" "tests_failed" "${test_status}" "${patch_sha256}"
exit 1
