FROM registry.home.mrdvince.me/homelab/builder:1.4.3

# renovate: datasource=npm depName=renovate
ARG RENOVATE_VERSION=43.280.0

RUN apk add --no-cache \
    nodejs \
    npm \
    && npm install --global "renovate@${RENOVATE_VERSION}" \
    && npm cache clean --force \
    && renovate --version \
    && nu --version \
    && helmfile --version \
    && helm version --short \
    && sops --version
