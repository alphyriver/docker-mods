# syntax=docker/dockerfile:1

# Use Ubuntu as the build stage so the installer downloads the glibc binary,
# which matches the target linuxserver/code-server container (Ubuntu Noble).
FROM ubuntu:noble AS downloader
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    mkdir -p /root-layer/usr/local/bin; \
    export HOME=/tmp/claude-install && mkdir -p "${HOME}"; \
    curl -fsSL https://claude.ai/install.sh | bash; \
    cp "${HOME}/.local/bin/claude" /root-layer/usr/local/bin/claude; \
    chmod 755 /root-layer/usr/local/bin/claude; \
    echo "Installed: $(/root-layer/usr/local/bin/claude --version 2>&1 || echo unknown)"

FROM scratch

LABEL maintainer="kazes"

COPY root/ /
COPY --from=downloader /root-layer/ /
