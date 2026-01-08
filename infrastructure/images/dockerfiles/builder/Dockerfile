FROM moby/buildkit:rootless

USER root

ARG YQ_VERSION=v4.50.1
ARG TRIVY_VERSION=0.68.2

RUN apk add --no-cache \
    curl \
    git \
    skopeo \
    && curl -sL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq \
    && curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin v${TRIVY_VERSION}

USER user
