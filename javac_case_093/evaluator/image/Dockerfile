FROM centos:7

ARG ANACONDA_VERSION=2.4.1
ARG REPO_URL
ARG BASE_COMMIT
ARG INSTANCE_ID

LABEL org.opencontainers.image.title="Java-C benchmark environment for ninia/jep" \
      org.opencontainers.image.description="Clean CentOS 7 base; patches and grading assets are injected at evaluation time" \
      org.opencontainers.image.source="https://github.com/ninia/jep" \
      benchmark.instance_id="${INSTANCE_ID}" \
      benchmark.base_commit="${BASE_COMMIT}"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN sed -i 's|^mirrorlist=|#mirrorlist=|g; s|^#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-Base.repo \
    && yum install -y bzip2 ca-certificates curl gcc gcc-c++ git java-1.8.0-openjdk-devel make patch tar which xz gzip \
    && yum clean all \
    && rm -rf /var/cache/yum

RUN curl -fsSL "https://repo.continuum.io/archive/Anaconda3-${ANACONDA_VERSION}-Linux-x86_64.sh" -o /tmp/anaconda.sh \
    && bash /tmp/anaconda.sh -b -p /opt/anaconda3 \
    && rm -f /tmp/anaconda.sh

RUN git init /testbed \
    && cd /testbed \
    && git fetch --no-tags "${REPO_URL}" "${BASE_COMMIT}" \
    && git checkout --detach "${BASE_COMMIT}" \
    && git config core.autocrlf false \
    && for ref in $(git for-each-ref --format='%(refname)' refs/heads refs/remotes refs/tags); do git update-ref -d "${ref}"; done \
    && git reflog expire --expire=now --all \
    && git gc --prune=now --aggressive \
    && test "$(git rev-parse HEAD)" = "${BASE_COMMIT}" \
    && test -z "$(git status --porcelain)" \
    && mkdir -p /benchmark /inputs /results

ENV JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk
ENV PATH=/opt/anaconda3/bin:${JAVA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=/opt/anaconda3/lib:${JAVA_HOME}/jre/lib/amd64/server:${LD_LIBRARY_PATH}
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

WORKDIR /testbed
CMD ["/bin/bash"]
