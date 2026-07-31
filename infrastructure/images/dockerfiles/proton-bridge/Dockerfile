# renovate: datasource=docker depName=golang
FROM golang:1.26.5-bookworm@sha256:1ecb7edf62a0408027bd5729dfd6b1b8766e578e8df93995b225dfd0944eb651 AS build

# renovate: datasource=github-releases depName=ProtonMail/proton-bridge extractVersion=^v(?<version>.*)$
ARG BRIDGE_VERSION=3.25.0

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        gcc \
        libc6-dev \
        libcbor-dev \
        libfido2-dev \
        libsecret-1-dev \
        libssl-dev \
        pkg-config \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

COPY . .

RUN make build-nogui BRIDGE_APP_VERSION="${BRIDGE_VERSION}" \
    && install -D -m 0755 bridge /out/protonmail-bridge

# renovate: datasource=docker depName=debian
FROM debian:bookworm-20260623-slim@sha256:60eac759739651111db372c07be67863818726f754804b8707c90979bda511df

ARG BRIDGE_VERSION=3.25.0

LABEL org.opencontainers.image.source="https://github.com/ProtonMail/proton-bridge"
LABEL org.opencontainers.image.description="Headless Proton Mail Bridge"
LABEL org.opencontainers.image.licenses="GPL-3.0-only"
LABEL org.opencontainers.image.version="${BRIDGE_VERSION}"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        libcbor0.8 \
        libfido2-1 \
        libsecret-1-0 \
        libssl3 \
        pass \
        tini \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10000 proton-bridge \
    && useradd --uid 10000 --gid 10000 --create-home --home-dir /var/lib/proton-bridge proton-bridge

COPY --from=build /out/protonmail-bridge /usr/local/bin/protonmail-bridge

USER proton-bridge
WORKDIR /var/lib/proton-bridge

VOLUME ["/var/lib/proton-bridge"]

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/protonmail-bridge"]
CMD ["--noninteractive"]
