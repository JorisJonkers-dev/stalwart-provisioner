FROM alpine:3.21

ARG STALWART_CLI_VERSION=1.0.7

LABEL org.opencontainers.image.source="https://github.com/JorisJonkers-dev/stalwart-provisioner"
LABEL org.opencontainers.image.description="Schema-driven Stalwart account and DKIM provisioner"

RUN apk add --no-cache ca-certificates curl gettext jq python3 tar xz \
  && arch="$(uname -m)" \
  && case "$arch" in \
    x86_64) target=x86_64-unknown-linux-musl ;; \
    aarch64) target=aarch64-unknown-linux-musl ;; \
    *) echo "unsupported arch: $arch" >&2; exit 1 ;; \
  esac \
  && curl -fsSL "https://github.com/stalwartlabs/cli/releases/download/v${STALWART_CLI_VERSION}/stalwart-cli-${target}.tar.xz" -o /tmp/cli.tar.xz \
  && tar -xJf /tmp/cli.tar.xz -C /tmp \
  && find /tmp -type f -name stalwart-cli -exec mv {} /usr/local/bin/stalwart-cli \; \
  && chmod +x /usr/local/bin/stalwart-cli \
  && rm -rf /tmp/*

COPY bin/stalwart-provisioner /usr/local/bin/stalwart-provisioner
COPY scripts/apply.sh /usr/local/bin/stalwart-provisioner-apply
COPY scripts/bootstrap.sh /usr/local/bin/stalwart-provisioner-bootstrap
COPY plan.ndjson.tmpl /opt/stalwart-provisioner/plan.ndjson.tmpl
COPY schema/ /opt/stalwart-provisioner/schema/
COPY examples/ /opt/stalwart-provisioner/examples/

RUN chmod +x \
  /usr/local/bin/stalwart-provisioner \
  /usr/local/bin/stalwart-provisioner-apply \
  /usr/local/bin/stalwart-provisioner-bootstrap

ENTRYPOINT ["stalwart-provisioner"]
CMD ["validate", "--help"]
