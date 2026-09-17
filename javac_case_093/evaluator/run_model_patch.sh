#!/usr/bin/env bash
set -uo pipefail

ROOT=/opt/javac_case_093
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
  "instance_id": "ninia__jep-79",
  "status": "${status}",
  "reason": "${reason}",
  "test_command": "python setup.py test",
  "test_exit_code": ${test_status},
  "model_patch": "${PATCH_PATH}",
  "model_patch_sha256": "${patch_sha256}",
  "logs": "${LOG_DIR}",
  "fail_to_pass": ["test_version_unsafe.TestVersionUnsafe.test_version_unsafe"],
  "pass_to_pass_count": 130
}
EOF
    cat "${RESULT_PATH}"
}

if [[ ! -f "${PATCH_PATH}" ]]; then
    write_result "failed" "model_patch_missing"
    exit 2
fi

patch_sha256="$(sha256sum "${PATCH_PATH}" | awk '{print $1}')"
# Normalize Windows CRLF patches before applying them to LF source files.
normalized_test_patch="${ROOT}/test_patch.normalized.diff"
normalized_model_patch="${ROOT}/model_patch.normalized.diff"
sed 's/\r$//' "${ROOT}/test_patch.diff" > "${normalized_test_patch}"
sed 's/\r$//' "${PATCH_PATH}" > "${normalized_model_patch}"

if ! tar -xzf "${ROOT}/jep_base_9eeb14c.tar.gz" -C "${BASE_DIR}"; then
    write_result "failed" "base_archive_extract_failed" null "${patch_sha256}"
    exit 2
fi

# The archived checkout was produced on Windows and contains CRLF source
# files. Normalize text sources before applying LF-based Git patches.
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

if ! git apply --check --whitespace=nowarn "${normalized_test_patch}" > "${LOG_DIR}/test_patch.log" 2>&1; then
    write_result "failed" "test_patch_apply_failed" null "${patch_sha256}"
    exit 2
fi

if ! git apply --whitespace=nowarn "${normalized_test_patch}" >> "${LOG_DIR}/test_patch.log" 2>&1; then
    write_result "failed" "test_patch_apply_failed" null "${patch_sha256}"
    exit 2
fi

if ! git apply --check --whitespace=nowarn "${normalized_model_patch}" > "${LOG_DIR}/model_patch.log" 2>&1; then
    write_result "failed" "model_patch_apply_failed" null "${patch_sha256}"
    exit 2
fi

if ! git apply --whitespace=nowarn "${normalized_model_patch}" >> "${LOG_DIR}/model_patch.log" 2>&1; then
    write_result "failed" "model_patch_apply_failed" null "${patch_sha256}"
    exit 2
fi

python setup.py clean > /dev/null 2>&1 || true
set +e
python setup.py test 2>&1 | tee "${LOG_DIR}/tests.log"
test_status=${PIPESTATUS[0]}
set -e

test_count=false
suite_ok=false
if grep -q "Ran 151 tests" "${LOG_DIR}/tests.log"; then
    test_count=true
fi
if grep -Eq '^OK( \(skipped=[0-9]+\))?$' "${LOG_DIR}/tests.log"; then
    suite_ok=true
fi

if [[ "${test_status}" -eq 0 && "${test_count}" == "true" && "${suite_ok}" == "true" ]]; then
    write_result "resolved" "all_tests_passed" "${test_status}" "${patch_sha256}"
    exit 0
fi

write_result "failed" "tests_failed" "${test_status}" "${patch_sha256}"
exit 1
