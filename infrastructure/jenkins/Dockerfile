ARG JENKINS_BASE=jenkins/jenkins@sha256:a660310e39ade10631f774bacd5219de767dfd08947ea5c32a739b5e5bb382c1
FROM ${JENKINS_BASE}

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates curl unzip python3 maven \
       git openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Docker client and plugins; the daemon runs on the host.
RUN set -eu; \
    install -m 0755 -d /etc/apt/keyrings; \
    curl -fsSL --retry 3 \
      https://download.docker.com/linux/debian/gpg \
      -o /etc/apt/keyrings/docker.asc; \
    chmod a+r /etc/apt/keyrings/docker.asc; \
    . /etc/os-release; \
    printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian %s stable\n' \
      "$(dpkg --print-architecture)" "$VERSION_CODENAME" \
      > /etc/apt/sources.list.d/docker.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      docker-ce-cli docker-buildx-plugin docker-compose-plugin; \
    rm -rf /var/lib/apt/lists/*

ARG TERRAFORM_VERSION=1.15.6

RUN set -eu; \
    test "$(dpkg --print-architecture)" = "amd64"; \
    mkdir -p /tmp/terraform-install; \
    cd /tmp/terraform-install; \
    archive="terraform_${TERRAFORM_VERSION}_linux_amd64.zip"; \
    checksums="terraform_${TERRAFORM_VERSION}_SHA256SUMS"; \
    release="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}"; \
    curl -fsSL --retry 3 "${release}/${archive}" -o "${archive}"; \
    curl -fsSL --retry 3 "${release}/${checksums}" -o "${checksums}"; \
    awk -v filename="${archive}" '$2 == filename {print}' \
      "${checksums}" > selected-checksum.txt; \
    test "$(wc -l < selected-checksum.txt)" -eq 1; \
    sha256sum -c selected-checksum.txt; \
    unzip -q "${archive}"; \
    install -m 0755 terraform /usr/local/bin/terraform; \
    cd /; \
    rm -rf /tmp/terraform-install

ARG AWS_CLI_VERSION=2.36.49

RUN set -eu; \
    curl -fsSL --retry 3 \
      "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWS_CLI_VERSION}.zip" \
      -o /tmp/awscliv2.zip; \
    unzip -q /tmp/awscliv2.zip -d /tmp; \
    /tmp/aws/install; \
    rm -rf /tmp/aws /tmp/awscliv2.zip

COPY --chown=jenkins:jenkins plugins.txt /usr/share/jenkins/ref/plugins.txt

USER jenkins

RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt
