# syntax=docker/dockerfile:1

# Build stage: fetch the latest Temurin LTS tarball matching glibc on Ubuntu Noble.
FROM ubuntu:noble AS downloader
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG JAVA_LTS_VERSION=21
ARG TARGETARCH=amd64

# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl jq tar \
    && rm -rf /var/lib/apt/lists/*

COPY root/ /root-layer/

RUN set -eux; \
    mkdir -p /root-layer/usr/local/lib; \
    case "${TARGETARCH}" in \
      amd64|x64) ARCH="x64" ;; \
      arm64|aarch64) ARCH="aarch64" ;; \
      *) echo "Unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    API="https://api.adoptium.net/v3/assets/feature_releases/${JAVA_LTS_VERSION}/ga?architecture=${ARCH}&heap_size=normal&image_type=jdk&jvm_impl=hotspot&os=linux&page=0&page_size=1&project=jdk&sort_method=DEFAULT&sort_order=DESC&vendor=eclipse"; \
    META=$(curl -fsSL "${API}"); \
    TARBALL_URL=$(echo "${META}" | jq -r '.[0].binaries[0].package.link'); \
    JDK_VERSION=$(echo "${META}" | jq -r '.[0].version_data.semver'); \
    echo "Downloading Temurin ${JDK_VERSION} from ${TARBALL_URL}"; \
    curl -fsSL "${TARBALL_URL}" -o /tmp/jdk.tar.gz; \
    mkdir -p /tmp/jdk-extract; \
    tar -xzf /tmp/jdk.tar.gz -C /tmp/jdk-extract --strip-components=1; \
    cp -a /tmp/jdk-extract /root-layer/usr/local/lib/jdk; \
    echo "${JDK_VERSION}" > /root-layer/usr/local/lib/jdk/.mod-version; \
    /root-layer/usr/local/lib/jdk/bin/java -version

FROM scratch

LABEL maintainer="kazes"

COPY --from=downloader /root-layer/ /
