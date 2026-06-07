FROM alpine:3 AS alloy

ARG TARGETARCH=amd64
ARG ALLOY_VERSION=1.16.2

RUN apk add --no-cache ca-certificates unzip wget \
    && wget -q -O /tmp/alloy.zip "https://github.com/grafana/alloy/releases/download/v${ALLOY_VERSION}/alloy-linux-${TARGETARCH}.zip" \
    && wget -q -O /tmp/SHA256SUMS "https://github.com/grafana/alloy/releases/download/v${ALLOY_VERSION}/SHA256SUMS" \
    && grep "alloy-linux-${TARGETARCH}.zip$" /tmp/SHA256SUMS | (cd /tmp && sha256sum -c -) \
    && unzip -q /tmp/alloy.zip -d /tmp/alloy \
    && install -m 0755 "/tmp/alloy/alloy-linux-${TARGETARCH}" /rootfs/alloy \
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

FROM scratch

COPY --from=alloy /rootfs/ /

ENTRYPOINT ["/alloy"]
