# syntax=docker/dockerfile:1

FROM --platform=${BUILDPLATFORM} alpine:3.20 AS downloader

ARG TARGETPLATFORM
ARG CLAUDE_VERSION=""

RUN apk add --no-cache curl bash

RUN set -eux; \
    case "${TARGETPLATFORM}" in \
        "linux/amd64")  PLATFORM="linux-x64"   ;; \
        "linux/arm64")  PLATFORM="linux-arm64"  ;; \
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
