FROM centos:7

ARG ANACONDA_VERSION=2.4.1

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN sed -i 's|^mirrorlist=|#mirrorlist=|g; s|^#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-Base.repo \
    && yum install -y \
        bzip2 ca-certificates curl gcc gcc-c++ git \
        java-1.8.0-openjdk-devel make patch tar which xz gzip \
    && yum clean all \
    && rm -rf /var/cache/yum

RUN curl -fsSL "https://repo.continuum.io/archive/Anaconda3-${ANACONDA_VERSION}-Linux-x86_64.sh" \
        -o /tmp/anaconda.sh \
    && bash /tmp/anaconda.sh -b -p /opt/anaconda3 \
    && rm -f /tmp/anaconda.sh

ENV JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk
ENV PATH=/opt/anaconda3/bin:${JAVA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=/opt/anaconda3/lib:${JAVA_HOME}/jre/lib/amd64/server:${JAVA_HOME}/jre/lib/amd64
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

WORKDIR /opt/javac_case_093

COPY source/base_9eeb14c.tar.gz /opt/javac_case_093/jep_base_9eeb14c.tar.gz
COPY source/fix_d145675.tar.gz /opt/javac_case_093/jep_fix_d145675.tar.gz
COPY patches/test_patch.diff /opt/javac_case_093/test_patch.diff
COPY docker/run_case.sh /opt/javac_case_093/run_case.sh

RUN chmod +x /opt/javac_case_093/run_case.sh \
    && python --version \
    && python -c "import ctypes; f=ctypes.pythonapi.Py_GetVersion; f.restype=ctypes.c_char_p; print(repr(f())); print('Py_GetVersion_length=' + str(len(f())))" \
    && javac -version \
    && gcc --version \
    && ldd --version

CMD ["/opt/javac_case_093/run_case.sh"]
