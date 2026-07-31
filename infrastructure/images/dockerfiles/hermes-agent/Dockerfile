ARG HERMES_IMAGE=docker.io/nousresearch/hermes-agent:v2026.7.1@sha256:b6c019227889e6675424a2b6223b2cafdd36bf7d1048d1ddd8e043b880d6cc0f

FROM ${HERMES_IMAGE} AS upstream

FROM upstream AS tools

ARG TERRAFORM_VERSION=1.14.8
ARG TERRAFORM_SHA256=56a5d12f47cbc1c6bedb8f5426ae7d5df984d1929572c24b56f4c82e9f9bf709
ARG TERRAGRUNT_VERSION=1.0.0
ARG TERRAGRUNT_SHA256=98bffc93e6f8a07809842cd402f2b66b2935139911e7c513d38425a352c777b2
ARG SOPS_VERSION=3.12.2
ARG SOPS_SHA256=14e2e1ba3bef31e74b70cf0b674f6443c80f6c5f3df15d05ffc57c34851b4998
ARG HELM_VERSION=4.2.0
ARG HELM_SHA256=97dbeb971be4ac4b27e3839976d9564c0fb35c6f3b1da89dd1e292d236af4096
ARG HELMFILE_VERSION=1.5.2
ARG HELMFILE_SHA256=96e342ff19a45c2e36371f93cf6264f3ef285bbde0fc363e56cb53bdef3df1ff
ARG KUBECTL_VERSION=1.36.2
ARG KUBECTL_SHA256=1e9045ec32bea85da43de85f0065358529ea7c7a152eca78154fba5b58c27d82
ARG GLAB_VERSION=1.101.0
ARG GLAB_SHA256=f8f40309a622416b769a455a85509bae7800070cd023466f2d33d8ee82f3fc61
ARG YQ_VERSION=4.52.5
ARG YQ_SHA256=75d893a0d5940d1019cb7cdc60001d9e876623852c31cfc6267047bc31149fa9
ARG NU_VERSION=0.114.0
ARG NU_SHA256=3896777ebf3678f6d41736a5e995ba8360b338eb73c713254fc024e08ec72289

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends unzip \
    && rm -rf /var/lib/apt/lists/* \
    && install -d /out/bin /out/helm \
    && curl -fsSL --retry 3 -o /tmp/terraform.zip \
        "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
    && echo "${TERRAFORM_SHA256}  /tmp/terraform.zip" | sha256sum -c - \
    && unzip -q /tmp/terraform.zip -d /out/bin terraform \
    && curl -fsSL --retry 3 -o /out/bin/terragrunt \
        "https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_amd64" \
    && echo "${TERRAGRUNT_SHA256}  /out/bin/terragrunt" | sha256sum -c - \
    && curl -fsSL --retry 3 -o /out/bin/sops \
        "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.amd64" \
    && echo "${SOPS_SHA256}  /out/bin/sops" | sha256sum -c - \
    && curl -fsSL --retry 3 -o /tmp/helm.tar.gz \
        "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" \
    && echo "${HELM_SHA256}  /tmp/helm.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/helm.tar.gz -C /tmp \
    && install /tmp/linux-amd64/helm /out/bin/helm \
    && curl -fsSL --retry 3 -o /tmp/helmfile.tar.gz \
        "https://github.com/helmfile/helmfile/releases/download/v${HELMFILE_VERSION}/helmfile_${HELMFILE_VERSION}_linux_amd64.tar.gz" \
    && echo "${HELMFILE_SHA256}  /tmp/helmfile.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/helmfile.tar.gz -C /out/bin helmfile \
    && curl -fsSL --retry 3 -o /out/bin/kubectl \
        "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && echo "${KUBECTL_SHA256}  /out/bin/kubectl" | sha256sum -c - \
    && curl -fsSL --retry 3 -o /tmp/glab.tar.gz \
        "https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads/glab_${GLAB_VERSION}_linux_amd64.tar.gz" \
    && echo "${GLAB_SHA256}  /tmp/glab.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/glab.tar.gz -C /tmp bin/glab \
    && install /tmp/bin/glab /out/bin/glab \
    && curl -fsSL --retry 3 -o /out/bin/yq \
        "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64" \
    && echo "${YQ_SHA256}  /out/bin/yq" | sha256sum -c - \
    && curl -fsSL --retry 3 -o /tmp/nu.tar.gz \
        "https://github.com/nushell/nushell/releases/download/${NU_VERSION}/nu-${NU_VERSION}-x86_64-unknown-linux-gnu.tar.gz" \
    && echo "${NU_SHA256}  /tmp/nu.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/nu.tar.gz -C /tmp \
    && install "/tmp/nu-${NU_VERSION}-x86_64-unknown-linux-gnu/nu" /out/bin/nu \
    && chmod 0755 /out/bin/* \
    && PATH="/out/bin:${PATH}" HELM_DATA_HOME=/out/helm \
        helmfile init --force \
    && rm -rf /tmp/*

FROM upstream

LABEL org.opencontainers.image.source="https://github.com/NousResearch/hermes-agent" \
      org.opencontainers.image.description="hermes agent with the homelab cli toolchain" \
      org.opencontainers.image.version="2026.7.1-2"

ENV CHECKPOINT_DISABLE=1 \
    HELM_DATA_HOME=/opt/hermes/homelab-tools/helm

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends jq rsync \
    && rm -rf /var/lib/apt/lists/*

COPY --from=tools /out/bin/ /usr/local/bin/
COPY --from=tools /out/helm/ /opt/hermes/homelab-tools/helm/
COPY --chmod=0755 infrastructure/images/dockerfiles/hermes-agent/016-wait-for-signal /etc/cont-init.d/016-wait-for-signal

RUN terraform version \
    && terragrunt --version \
    && sops --version \
    && helm version --short \
    && helmfile --version \
    && kubectl version --client \
    && glab --version \
    && yq --version \
    && nu --version \
    && helm plugin list
