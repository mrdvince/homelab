FROM alpine:3 AS alloy

ARG TARGETARCH=amd64
ARG ALLOY_VERSION=1.16.2

RUN apk add --no-cache ca-certificates unzip wget \
    && wget -q -O /tmp/alloy.zip "https://github.com/grafana/alloy/releases/download/v${ALLOY_VERSION}/alloy-linux-${TARGETARCH}.zip" \
    && wget -q -O /tmp/SHA256SUMS "https://github.com/grafana/alloy/releases/download/v${ALLOY_VERSION}/SHA256SUMS" \
    && expected_sha256="$(awk -v file="alloy-linux-${TARGETARCH}.zip" '$2 == file { print $1 }' /tmp/SHA256SUMS)" \
    && printf '%s  %s\n' "${expected_sha256}" /tmp/alloy.zip | sha256sum -c - \
    && unzip -q /tmp/alloy.zip -d /tmp/alloy \
    && install -D -m 0755 "/tmp/alloy/alloy-linux-${TARGETARCH}" /rootfs/alloy \
    && install -d \
        /rootfs/etc/alloy \
        /rootfs/etc/ssl/certs \
        /rootfs/host/proc \
        /rootfs/host/rootfs \
        /rootfs/host/run/udev/data \
        /rootfs/host/sys \
        /rootfs/run/log/journal \
        /rootfs/tmp \
        /rootfs/var/lib/alloy/data \
        /rootfs/var/lib/docker/containers \
        /rootfs/var/log \
        /rootfs/var/log/journal \
    && cp /etc/ssl/certs/ca-certificates.crt /rootfs/etc/ssl/certs/ca-certificates.crt

FROM debian:13-slim AS journal-libs

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends libsystemd0 \
    && install -d /rootfs/lib/x86_64-linux-gnu \
    && cp \
        /lib/x86_64-linux-gnu/libcap.so.2* \
        /lib/x86_64-linux-gnu/libgcrypt.so.20* \
        /lib/x86_64-linux-gnu/libgpg-error.so.0* \
        /lib/x86_64-linux-gnu/liblz4.so.1* \
        /lib/x86_64-linux-gnu/liblzma.so.5* \
        /lib/x86_64-linux-gnu/libsystemd.so.0* \
        /lib/x86_64-linux-gnu/libzstd.so.1* \
        /rootfs/lib/x86_64-linux-gnu/

FROM gcr.io/distroless/base-debian12

COPY --from=alloy /rootfs/ /
COPY --from=journal-libs /rootfs/ /

ENTRYPOINT ["/alloy"]
