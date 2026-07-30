ARG BASE_IMAGE=debian:bookworm-20260623-slim@sha256:60eac759739651111db372c07be67863818726f754804b8707c90979bda511df

FROM ${BASE_IMAGE} AS tools

ARG CODEX_VERSION=0.146.0
ARG CODEX_SHA256=5ba3b9405543953081f661d0854d266f76e2abbe51d41349355a36de7673776a
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
ARG TALOSCTL_VERSION=1.13.4
ARG TALOSCTL_SHA256=aae1dadd238f9dfbc9790d117a114424b2d59200ee12872d0d9f89e178a69aae
ARG GLAB_VERSION=1.101.0
ARG GLAB_SHA256=f8f40309a622416b769a455a85509bae7800070cd023466f2d33d8ee82f3fc61
ARG GH_VERSION=2.96.0
ARG GH_SHA256=83d5c2ccad5498f58bf6368acb1ab32588cf43ab3a4b1c301bf36328b1c8bd60
ARG YQ_VERSION=4.52.5
ARG YQ_SHA256=75d893a0d5940d1019cb7cdc60001d9e876623852c31cfc6267047bc31149fa9
ARG NU_VERSION=0.114.0
ARG NU_SHA256=3896777ebf3678f6d41736a5e995ba8360b338eb73c713254fc024e08ec72289
ARG HOMEBREW_VERSION=6.0.13
ARG HOMEBREW_COMMIT=b2cfc03346d482f79886de108fee5dc49a6efc10

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl git tar unzip zstd \
    && rm -rf /var/lib/apt/lists/* \
    && install -d /out/bin /out/helm /out/homebrew/Homebrew \
    && curl -fsSL --retry 3 -o /tmp/codex.tar.gz \
        "https://github.com/openai/codex/releases/download/rust-v${CODEX_VERSION}/codex-x86_64-unknown-linux-musl.tar.gz" \
    && echo "${CODEX_SHA256}  /tmp/codex.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/codex.tar.gz -C /tmp \
    && install /tmp/codex-x86_64-unknown-linux-musl /out/bin/codex \
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
    && curl -fsSL --retry 3 -o /out/bin/talosctl \
        "https://github.com/siderolabs/talos/releases/download/v${TALOSCTL_VERSION}/talosctl-linux-amd64" \
    && echo "${TALOSCTL_SHA256}  /out/bin/talosctl" | sha256sum -c - \
    && curl -fsSL --retry 3 -o /tmp/glab.tar.gz \
        "https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads/glab_${GLAB_VERSION}_linux_amd64.tar.gz" \
    && echo "${GLAB_SHA256}  /tmp/glab.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/glab.tar.gz -C /tmp bin/glab \
    && install /tmp/bin/glab /out/bin/glab \
    && curl -fsSL --retry 3 -o /tmp/gh.tar.gz \
        "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz" \
    && echo "${GH_SHA256}  /tmp/gh.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/gh.tar.gz -C /tmp \
    && install "/tmp/gh_${GH_VERSION}_linux_amd64/bin/gh" /out/bin/gh \
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
    && git -C /out/homebrew/Homebrew init \
    && git -C /out/homebrew/Homebrew remote add origin https://github.com/Homebrew/brew.git \
    && git -C /out/homebrew/Homebrew fetch --depth 1 origin "${HOMEBREW_COMMIT}" \
    && git -C /out/homebrew/Homebrew checkout --detach FETCH_HEAD \
    && test "$(git -C /out/homebrew/Homebrew rev-parse HEAD)" = "${HOMEBREW_COMMIT}" \
    && install -d /out/homebrew/bin \
    && ln -s ../Homebrew/bin/brew /out/homebrew/bin/brew \
    && rm -rf /tmp/*

FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.source="https://github.com/openai/codex" \
      org.opencontainers.image.description="codex with the homelab cli toolchain and persistent linuxbrew" \
      org.opencontainers.image.version="0.146.0-3"

ENV CODEX_HOME=/opt/data/home/.codex \
    CODEX_SQLITE_HOME=/opt/data/home/.codex \
    HELM_DATA_HOME=/opt/codex/helm \
    HOME=/opt/data/home \
    HOMEBREW_NO_ANALYTICS=1 \
    KUBECONFIG=/etc/codex-kubernetes/config \
    PATH=/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin \
    XDG_CACHE_HOME=/opt/data/home/.cache \
    XDG_CONFIG_HOME=/opt/data/home/.config \
    XDG_DATA_HOME=/opt/data/home/.local/share

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        bubblewrap \
        build-essential \
        ca-certificates \
        curl \
        dnsutils \
        file \
        git \
        git-lfs \
        iproute2 \
        iputils-ping \
        jq \
        less \
        locales \
        make \
        netcat-openbsd \
        nodejs \
        npm \
        openssh-client \
        openssl \
        procps \
        python3 \
        python3-pip \
        python3-venv \
        ripgrep \
        rsync \
        shellcheck \
        skopeo \
        tini \
        unzip \
        xz-utils \
        zstd \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 1000 codex \
    && useradd --uid 1000 --gid 1000 --create-home --home-dir /home/codex --shell /bin/bash codex \
    && install -d -o codex -g codex \
        /home/linuxbrew/.linuxbrew \
        /opt/codex/helm \
        /opt/codex/homebrew \
        /opt/data/home \
        /opt/data/projects

COPY --from=tools /out/bin/ /usr/local/bin/
COPY --from=tools /out/helm/ /opt/codex/helm/
COPY --from=tools /out/homebrew/ /opt/codex/homebrew/
COPY --chmod=0755 infrastructure/images/dockerfiles/codex/codex-remote-control /usr/local/bin/codex-remote-control
COPY infrastructure/images/dockerfiles/codex/codex-profile.sh /etc/profile.d/codex.sh

RUN codex --version \
    && codex remote-control --help >/dev/null \
    && terraform version \
    && terragrunt --version \
    && sops --version \
    && helm version --short \
    && helmfile --version \
    && kubectl version --client \
    && talosctl version --client \
    && glab --version \
    && gh --version \
    && yq --version \
    && nu --version \
    && helm plugin list \
    && /opt/codex/homebrew/bin/brew --version

USER 1000:1000
WORKDIR /opt/data/projects

ENTRYPOINT ["/usr/bin/tini", "--"]
