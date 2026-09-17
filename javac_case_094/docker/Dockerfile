FROM eclipse-temurin:8-jdk-jammy

ARG DEBIAN_FRONTEND=noninteractive
ARG PYTHON_VERSION=3.5.3

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl file g++ gcc git make patch tar xz-utils \
        zlib1g-dev libbz2-dev libffi-dev liblzma-dev libncurses5-dev \
        libreadline-dev libsqlite3-dev libssl-dev tk-dev uuid-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz" \
        -o /tmp/Python-${PYTHON_VERSION}.tgz \
    && mkdir -p /tmp/python-src \
    && tar -xzf /tmp/Python-${PYTHON_VERSION}.tgz -C /tmp/python-src --strip-components=1 \
    && cd /tmp/python-src \
    && ./configure --prefix=/opt/python-${PYTHON_VERSION} --enable-shared \
    && make -j"$(nproc)" \
    && make install \
    && echo "/opt/python-${PYTHON_VERSION}/lib" > /etc/ld.so.conf.d/python-${PYTHON_VERSION}.conf \
    && ldconfig \
    && ln -sf /opt/python-${PYTHON_VERSION}/bin/python3.5 /usr/local/bin/python \
    && ln -sf /opt/python-${PYTHON_VERSION}/bin/python3.5 /usr/local/bin/python3 \
    && rm -rf /tmp/Python-${PYTHON_VERSION}.tgz /tmp/python-src

ENV JAVA_HOME=/opt/java/openjdk
ENV PATH=/opt/python-3.5.3/bin:${JAVA_HOME}/bin:${PATH}
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

WORKDIR /opt/javac_case_094

COPY source/base_bc2edaf.tar.gz /opt/javac_case_094/jep_base_bc2edaf.tar.gz
COPY source/fix_8144158.tar.gz /opt/javac_case_094/jep_fix_8144158.tar.gz
COPY patches/gold_patch.diff /opt/javac_case_094/gold_patch.diff
COPY patches/test_patch.diff /opt/javac_case_094/test_patch.diff
COPY docker/run_case.sh /opt/javac_case_094/run_case.sh

RUN chmod +x /opt/javac_case_094/run_case.sh \
    && python --version \
    && javac -version

CMD ["/opt/javac_case_094/run_case.sh"]
