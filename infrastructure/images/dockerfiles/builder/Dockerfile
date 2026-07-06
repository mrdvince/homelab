FROM docker:29

ARG YQ_VERSION=v4.50.1
ARG HELM_VERSION=v4.0.5
ARG TERRAGRUNT_VERSION=v0.97.2
ARG HELMFILE_VERSION=1.2.3

RUN apk add --no-cache \
    bash \
    curl \
    git \
    nushell \
    tar \
    gzip \
    skopeo \
    sops \
    && apk upgrade --no-cache \
    && curl -sL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq \
    && curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" | tar xz \
    && mv linux-amd64/helm /usr/local/bin/helm \
    && rm -rf linux-amd64 \
    && curl -fsSL -o /tmp/helmfile.tar.gz "https://github.com/helmfile/helmfile/releases/download/v${HELMFILE_VERSION}/helmfile_${HELMFILE_VERSION}_linux_amd64.tar.gz" \
    && tar -xzf /tmp/helmfile.tar.gz -C /tmp helmfile \
    && mv /tmp/helmfile /usr/local/bin/helmfile \
    && rm -f /tmp/helmfile.tar.gz \
    && chmod +x /usr/local/bin/helmfile \
    && helmfile init --force \
    && curl -fsSL -o /usr/local/bin/terragrunt "https://github.com/gruntwork-io/terragrunt/releases/download/${TERRAGRUNT_VERSION}/terragrunt_linux_amd64" \
    && chmod +x /usr/local/bin/terragrunt
