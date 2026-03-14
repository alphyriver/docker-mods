# syntax=docker/dockerfile:1

# Builder always runs on amd64 for speed and Kaniko compatibility.
# The TARGETPLATFORM build-arg controls which binary the installer fetches.
# hadolint ignore=DL3029
FROM --platform=linux/amd64 ubuntu:noble AS downloader

ARG TARGETPLATFORM=linux/amd64
ARG CLAUDE_VERSION=""

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    case "${TARGETPLATFORM}" in \
        "linux/amd64")  export PLATFORM="linux-x64"   ;; \
        "linux/arm64")  export PLATFORM="linux-arm64"  ;; \
        *) echo "Unsupported platform: ${TARGETPLATFORM}" && exit 1 ;; \
    esac; \
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
