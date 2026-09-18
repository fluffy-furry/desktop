# SPDX-License-Identifier: GPL-3.0-only
# Adapted from Brendan Forster (Shiftkey)'s Linux packaging actions:
# https://github.com/shiftkey/desktop-ubuntu-arm64-packaging/tree/9be09c4b945873e6509baaf690d457aae08cf901
# https://github.com/shiftkey/desktop-ubuntu-amd64-packaging/tree/ea7b7a6a940a6b907b160b946439c5c7a516f9f1
# Updated for upstream Node 24, Ubuntu 24.04 and this fork's Linux packages.
FROM --platform=linux/amd64 ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG TARGET_ARCH=x64
ARG NODE_VERSION=24.15.0

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential python3 pkg-config ca-certificates curl xz-utils git \
    autoconf automake jq fakeroot desktop-file-utils libsecret-1-dev rpm \
    && rm -rf /var/lib/apt/lists/*

# The container and Node stay x64, as in Shiftkey's ARM packaging action.
# Only compiled application dependencies use the AArch64 toolchain.
RUN set -e; case "$TARGET_ARCH" in \
      x64) ;; \
      arm64) \
        apt-get update && apt-get install -y --no-install-recommends \
          gcc-aarch64-linux-gnu g++-aarch64-linux-gnu binutils-aarch64-linux-gnu; \
        rm -rf /var/lib/apt/lists/* ;; \
      *) printf 'Unsupported target architecture: %s\n' "$TARGET_ARCH" >&2; exit 1 ;; \
    esac

RUN cd /tmp && \
    curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" && \
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt" \
      | grep "  node-v${NODE_VERSION}-linux-x64.tar.xz$" | sha256sum -c - && \
    tar -xJf "node-v${NODE_VERSION}-linux-x64.tar.xz" --strip-components=1 -C /usr/local && \
    rm "node-v${NODE_VERSION}-linux-x64.tar.xz"

ENV TARGET_ARCH=${TARGET_ARCH}
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
WORKDIR /github/workspace
ENTRYPOINT ["/entrypoint.sh"]
