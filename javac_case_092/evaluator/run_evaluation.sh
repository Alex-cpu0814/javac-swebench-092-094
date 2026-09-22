#!/usr/bin/env bash
set -uo pipefail

readonly BASE_COMMIT="${BENCHMARK_BASE_COMMIT:?BENCHMARK_BASE_COMMIT is required}"
readonly MODEL_PATCH="/inputs/model.patch"
readonly TEST_PATCH="/inputs/test.patch"
readonly CASE_ADAPTER="/benchmark/case_adapter.sh"
readonly RESULT_DIR="/results"
readonly BUILD_LOG="${RESULT_DIR}/project-build.raw.log"
readonly TEST_LOG="${RESULT_DIR}/tests.raw.log"
readonly MODEL_LOG="${RESULT_DIR}/model-patch.raw.log"
readonly TEST_PATCH_LOG="${RESULT_DIR}/test-patch.raw.log"
readonly EVENTS_FILE="${RESULT_DIR}/events.jsonl"
readonly PHASE_FILE="${RESULT_DIR}/phase.json"
readonly RUN_ID="${BENCHMARK_RUN_ID:-unknown-run}"

mkdir -p "${RESULT_DIR}"

utc_now() {
    date -u +"%Y-%m-%dT%H:%M:%S.%3NZ"
}

emit_event() {
    local level="$1"
    local phase="$2"
    local event="$3"
    local message="$4"
    local extra="${5:-}"
    printf '{"schema_version":"3.0","timestamp":"%s","level":"%s","operation_id":"%s","phase":"%s","event":"%s","message":"%s"%s}\n' \
        "$(utc_now)" "${level}" "${RUN_ID}" "${phase}" "${event}" "${message}" "${extra}" \
        >> "${EVENTS_FILE}"
}

write_phase() {
    local phase="$1"
    local outcome="$2"
    local reason="$3"
    local test_exit_code="${4:-null}"
    cat > "${PHASE_FILE}" <<EOF
{
  "phase": "${phase}",
  "outcome": "${outcome}",
  "reason": "${reason}",
  "test_exit_code": ${test_exit_code}
}
EOF
}

fail_infrastructure() {
    local phase="$1"
    local reason="$2"
    emit_event "ERROR" "${phase}" "${reason}" "Evaluation infrastructure failed"
    write_phase "${phase}" "infrastructure_error" "${reason}" null
    exit 2
}

reject_candidate() {
    local phase="$1"
    local reason="$2"
    emit_event "WARN" "${phase}" "${reason}" "Candidate could not complete this phase"
    write_phase "${phase}" "unresolved" "${reason}" null
    exit 1
}

emit_event "INFO" "preflight" "preflight.started" "Checking protected evaluation assets"
[[ -f "${MODEL_PATCH}" ]] || fail_infrastructure "preflight" "model_patch_missing"
[[ -f "${TEST_PATCH}" ]] || fail_infrastructure "preflight" "test_patch_missing"
[[ -f "${CASE_ADAPTER}" ]] || fail_infrastructure "preflight" "case_adapter_missing"

# shellcheck source=/dev/null
source "${CASE_ADAPTER}" || fail_infrastructure "preflight" "case_adapter_load_failed"
declare -F build_project >/dev/null || fail_infrastructure "preflight" "build_function_missing"
declare -F run_project_tests >/dev/null || fail_infrastructure "preflight" "test_function_missing"

cd /testbed || fail_infrastructure "workspace" "testbed_missing"
git reset --hard "${BASE_COMMIT}" > /dev/null 2>&1 \
    || fail_infrastructure "workspace" "base_reset_failed"
git clean -fdx > /dev/null 2>&1 \
    || fail_infrastructure "workspace" "base_clean_failed"
[[ "$(git rev-parse HEAD)" == "${BASE_COMMIT}" ]] \
    || fail_infrastructure "workspace" "base_commit_mismatch"

sed 's/\r$//' "${MODEL_PATCH}" > /tmp/model.patch
sed 's/\r$//' "${TEST_PATCH}" > /tmp/test.patch

# Validate the protected patch against the untouched Base before the candidate
# can affect its applicability.
if ! git apply --check --whitespace=nowarn /tmp/test.patch > "${TEST_PATCH_LOG}" 2>&1; then
    fail_infrastructure "preflight" "protected_test_patch_invalid"
fi
emit_event "INFO" "preflight" "preflight.completed" "Protected assets are valid"

phase_started=$(date +%s%3N)
emit_event "INFO" "model_patch" "model_patch.started" "Applying candidate patch"
if ! git apply --check --whitespace=nowarn /tmp/model.patch > "${MODEL_LOG}" 2>&1; then
    reject_candidate "model_patch" "model_patch_apply_failed"
fi
if ! git apply --whitespace=nowarn /tmp/model.patch >> "${MODEL_LOG}" 2>&1; then
    reject_candidate "model_patch" "model_patch_apply_failed"
fi
phase_duration=$(( $(date +%s%3N) - phase_started ))
emit_event "INFO" "model_patch" "model_patch.completed" "Candidate patch applied" ",\"duration_ms\":${phase_duration}"

phase_started=$(date +%s%3N)
emit_event "INFO" "test_patch" "test_patch.started" "Applying protected test patch"
if ! git apply --check --whitespace=nowarn /tmp/test.patch >> "${TEST_PATCH_LOG}" 2>&1; then
    reject_candidate "test_patch" "candidate_conflicts_with_test_patch"
fi
if ! git apply --whitespace=nowarn /tmp/test.patch >> "${TEST_PATCH_LOG}" 2>&1; then
    reject_candidate "test_patch" "candidate_conflicts_with_test_patch"
fi
phase_duration=$(( $(date +%s%3N) - phase_started ))
emit_event "INFO" "test_patch" "test_patch.completed" "Protected test patch applied" ",\"duration_ms\":${phase_duration}"

phase_started=$(date +%s%3N)
emit_event "INFO" "project_build" "project_build.started" "Building patched project"
if ! build_project > "${BUILD_LOG}" 2>&1; then
    reject_candidate "project_build" "project_build_failed"
fi
phase_duration=$(( $(date +%s%3N) - phase_started ))
emit_event "INFO" "project_build" "project_build.completed" "Patched project built" ",\"duration_ms\":${phase_duration}"

phase_started=$(date +%s%3N)
emit_event "INFO" "tests" "tests.started" "Running project test suite"
set +e
run_project_tests > "${TEST_LOG}" 2>&1
test_exit_code=$?
set -e
phase_duration=$(( $(date +%s%3N) - phase_started ))
emit_event "INFO" "tests" "tests.completed" "Project test suite completed" ",\"duration_ms\":${phase_duration},\"test_exit_code\":${test_exit_code}"

write_phase "tests_complete" "completed" "tests_completed" "${test_exit_code}"
if [[ "${test_exit_code}" -eq 0 ]]; then
    exit 0
fi
exit 1
