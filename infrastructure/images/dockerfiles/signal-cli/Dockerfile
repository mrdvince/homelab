# renovate: datasource=docker depName=azul/zulu-openjdk
FROM registry.home.mrdvince.me/azul/zulu-openjdk:25-jre-headless@sha256:d7674a8d76c574b94f87628bcf379f08a10c14dd8bee88507b9144c0e46d5324

# renovate: datasource=github-releases depName=AsamK/signal-cli extractVersion=^v(?<version>.*)$
ARG SIGNAL_CLI_VERSION=0.14.5
ARG SIGNAL_CLI_SHA256=62d38ebfef3988d78f437e7328183b75ee549d111382e66c1af70d3ebd3cd7a7

LABEL org.opencontainers.image.source="https://github.com/AsamK/signal-cli"
LABEL org.opencontainers.image.description="signal-cli HTTP daemon for Hermes Agent"
LABEL org.opencontainers.image.licenses="GPL-3.0-only"

ADD https://github.com/AsamK/signal-cli/releases/download/v${SIGNAL_CLI_VERSION}/signal-cli-${SIGNAL_CLI_VERSION}.tar.gz /tmp/signal-cli.tar.gz

RUN printf '%s  %s\n' "${SIGNAL_CLI_SHA256}" /tmp/signal-cli.tar.gz | sha256sum -c - \
    && apt-get update \
    && apt-get install -y --no-install-recommends qrencode \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10000 signal-cli \
    && useradd --uid 10000 --gid 10000 --create-home --home-dir /var/lib/signal-cli signal-cli \
    && tar -xzf /tmp/signal-cli.tar.gz -C /opt \
    && ln -s "/opt/signal-cli-${SIGNAL_CLI_VERSION}/bin/signal-cli" /usr/local/bin/signal-cli \
    && rm /tmp/signal-cli.tar.gz \
    && chown -R signal-cli:signal-cli /var/lib/signal-cli

USER signal-cli
WORKDIR /var/lib/signal-cli

VOLUME ["/var/lib/signal-cli"]
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/signal-cli", "--config=/var/lib/signal-cli"]
CMD ["daemon", "--http", "0.0.0.0:8080"]
