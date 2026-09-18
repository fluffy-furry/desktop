#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Adapted from Shiftkey's desktop-ubuntu-{amd64,arm64}-packaging entrypoints.
# Build order is retained; use this repository's pinned Node/Yarn and target arch.
set -euo pipefail

export TARGET_ARCH=${1:-${TARGET_ARCH:-x64}}
export npm_config_arch="$TARGET_ARCH"
case "$TARGET_ARCH" in
    x64)
        export AS=as STRIP=strip AR=ar CC=gcc CPP=cpp CXX=g++ LD=ld
        export PKG_CONFIG_LIBDIR=/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/share/pkgconfig
        ;;
    arm64)
        export AS=aarch64-linux-gnu-as STRIP=aarch64-linux-gnu-strip
        export AR=aarch64-linux-gnu-ar CC=aarch64-linux-gnu-gcc
        export CPP=aarch64-linux-gnu-cpp CXX=aarch64-linux-gnu-g++ LD=aarch64-linux-gnu-ld
        export PKG_CONFIG_LIBDIR=/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/share/pkgconfig
        ;;
    *) printf 'Unsupported target architecture: %s\n' "$TARGET_ARCH" >&2; exit 1 ;;
esac
export PKG_CONFIG_PATH="$PKG_CONFIG_LIBDIR"
export JOBS="$(nproc)" npm_config_jobs="$(nproc)"
export MAKEFLAGS="-j$JOBS" UV_THREADPOOL_SIZE="$JOBS" DPKG_DEB_THREADS_MAX="$JOBS"

test "$(node -p process.arch)" = x64
test "$(node -p process.versions.node)" = "$(tr -d '[:space:]' < .node-version)"
git config --global --add safe.directory "$PWD"
workspace_owner=$(stat -c '%u:%g' .)
trap 'if [ -d dist ]; then chown -R "$workspace_owner" dist; fi' EXIT

node vendor/yarn-1.21.1.js install --frozen-lockfile --production=false
node vendor/yarn-1.21.1.js run postinstall
node vendor/yarn-1.21.1.js build:prod
NODE_ENV=production node vendor/yarn-1.21.1.js run package
