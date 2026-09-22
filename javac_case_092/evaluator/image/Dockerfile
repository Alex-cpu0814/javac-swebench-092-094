FROM docker.io/library/eclipse-temurin:8-jdk-jammy@sha256:d57e5d0e3e5dd4cabb74feccfdb36249a58c76a3354a33ee8737813df93b7e0d

ARG DEBIAN_FRONTEND=noninteractive
ARG PYTHON_VERSION=3.5.3
ARG PYTHON_SHA256=d8890b84d773cd7059e597dbefa510340de8336ec9b9e9032bf030f19291565a

LABEL org.opencontainers.image.title="Java-C benchmark environment for ninia/jep" \
      org.opencontainers.image.description="Clean base environment; patches and grading assets are injected at evaluation time" \
      org.opencontainers.image.source="https://github.com/ninia/jep"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        file \
        g++ \
        gcc \
        git \
        make \
        patch \
        tar \
        xz-utils \
        zlib1g-dev \
        libbz2-dev \
        libffi-dev \
        liblzma-dev \
        libncurses5-dev \
        libreadline-dev \
        libsqlite3-dev \
        libssl-dev \
        tk-dev \
        uuid-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz" \
        -o "/tmp/Python-${PYTHON_VERSION}.tgz" \
    && echo "${PYTHON_SHA256}  /tmp/Python-${PYTHON_VERSION}.tgz" | sha256sum -c - \
    && mkdir -p /tmp/python-src \
    && tar -xzf "/tmp/Python-${PYTHON_VERSION}.tgz" -C /tmp/python-src --strip-components=1 \
    && cd /tmp/python-src \
    && ./configure --prefix="/opt/python-${PYTHON_VERSION}" --enable-shared \
    && make -j"$(nproc)" \
    && make install \
    && echo "/opt/python-${PYTHON_VERSION}/lib" > "/etc/ld.so.conf.d/python-${PYTHON_VERSION}.conf" \
    && ldconfig \
    && ln -sf "/opt/python-${PYTHON_VERSION}/bin/python3.5" /usr/local/bin/python \
    && ln -sf "/opt/python-${PYTHON_VERSION}/bin/python3.5" /usr/local/bin/python3 \
    && rm -rf "/tmp/Python-${PYTHON_VERSION}.tgz" /tmp/python-src

ARG EXTRA_APT_PACKAGES=""
RUN if [[ -n "${EXTRA_APT_PACKAGES}" ]]; then \
        apt-get update \
        && apt-get install -y --no-install-recommends ${EXTRA_APT_PACKAGES} \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/*; \
    fi

ARG REPO_URL
ARG BASE_COMMIT
ARG INSTANCE_ID

LABEL benchmark.instance_id="${INSTANCE_ID}" \
      benchmark.base_commit="${BASE_COMMIT}"

RUN git clone --no-checkout "${REPO_URL}" /testbed \
    && cd /testbed \
    && git checkout --detach "${BASE_COMMIT}" \
    && git remote remove origin \
    && git config core.autocrlf false \
    && git for-each-ref --format='delete %(refname)' refs/heads refs/remotes refs/tags \
        | git update-ref --stdin \
    && git reflog expire --expire=now --all \
    && git gc --prune=now \
    && test "$(git rev-parse HEAD)" = "${BASE_COMMIT}" \
    && test -z "$(git status --porcelain)" \
    && mkdir -p /benchmark /inputs /results

ENV JAVA_HOME=/opt/java/openjdk
ENV PATH=/opt/python-3.5.3/bin:${JAVA_HOME}/bin:${PATH}
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

WORKDIR /testbed

CMD ["/bin/bash"]
