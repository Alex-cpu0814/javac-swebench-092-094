#!/usr/bin/env bash

# Case-specific build and test functions sourced by run_evaluation.sh.

build_project() {
    python setup.py clean >/dev/null 2>&1 || true
    python setup.py build

    CASE_NATIVE_LIB="$(find build -type f -name 'jep*.so' -print -quit)"
    [[ -n "${CASE_NATIVE_LIB}" ]] || return 10
    CASE_NATIVE_DIR="$(dirname "${CASE_NATIVE_LIB}")"
    ln -sf "$(basename "${CASE_NATIVE_LIB}")" "${CASE_NATIVE_DIR}/libjep.so"

    CASE_PROJECT_VERSION="$(python -c "ns={}; exec(open('jep/version.py').read(), ns); print(ns['VERSION'])")" \
        || return 11
    CASE_CLASSPATH="build/java/jep-${CASE_PROJECT_VERSION}.jar"
    CASE_CLASSPATH="${CASE_CLASSPATH}:build/java/jep.test-${CASE_PROJECT_VERSION}.jar"
    for CASE_JAR in tests/lib/*.jar; do
        [[ -f "${CASE_JAR}" ]] && CASE_CLASSPATH="${CASE_CLASSPATH}:${CASE_JAR}"
    done

    export LD_LIBRARY_PATH="/opt/anaconda3/lib:${CASE_NATIVE_DIR}:${LD_LIBRARY_PATH:-}"
    local python_lib
    python_lib="$(find /opt/anaconda3/lib -maxdepth 1 -type f \
        \( -name 'libpython3.5m.so*' -o -name 'libpython3.5.so*' \) \
        | head -n 1)"
    if [[ -n "${python_lib}" ]]; then
        export LD_PRELOAD="${python_lib}${LD_PRELOAD:+:${LD_PRELOAD}}"
    fi
}

run_project_tests() {
    java -classpath "${CASE_CLASSPATH}" \
        -Djava.library.path="${CASE_NATIVE_DIR}" \
        jep.Run runtests.py
}
