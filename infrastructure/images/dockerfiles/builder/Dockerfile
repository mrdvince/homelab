FROM docker:29

ARG YQ_VERSION=v4.50.1
ARG TRIVY_VERSION=0.68.2
ARG HELM_VERSION=v4.0.1
ARG TERRAGRUNT_VERSION=v0.97.2
ARG HELMFILE_VERSION=v1.1.7

RUN apk add --no-cache \
    curl \
    git \
    tar \
    gzip \
    skopeo \
    && curl -sL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq \
    && curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin v${TRIVY_VERSION} \
    && curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" | tar xz \
    && mv linux-amd64/helm /usr/local/bin/helm \
    && rm -rf linux-amd64 \
    && curl -fsSL -o /usr/local/bin/helmfile "https://github.com/helmfile/helmfile/releases/download/${HELMFILE_VERSION}/helmfile_linux_amd64" \
    && chmod +x /usr/local/bin/helmfile \
    && curl -fsSL -o /usr/local/bin/terragrunt "https://github.com/gruntwork-io/terragrunt/releases/download/${TERRAGRUNT_VERSION}/terragrunt_linux_amd64" \
    && chmod +x /usr/local/bin/terragrunt
