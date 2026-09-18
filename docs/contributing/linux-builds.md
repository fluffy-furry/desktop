# Linux builds

This fork follows official GitHub Desktop stable releases. Its Linux port carries
forward [Shiftkey's work](../../CREDITS.md). The [inherited README](../../README.md)
describes Shiftkey's feeds and a community AUR package; those sources do not
contain this fork's builds. Download this fork's packages from [our releases](https://github.com/fluffy-furry/desktop/releases).

The Linux workflow builds `x64` and `arm64` applications. Its x64 Docker image
uses native x64 Node.js for both builds; the ARM64 target uses GNU AArch64
cross-compilers. It builds the application once per architecture, then packages
that output as `.deb`, `.rpm`, `.AppImage`, and Arch `.pkg.tar.zst`. The ARM64
Arch package targets Arch Linux ARM. Building does not use QEMU.

Package tests run on matching native x64 and ARM64 runners. Ubuntu and Debian
install and remove `.deb` packages. Fedora and openSUSE install and remove
`.rpm` packages. Arch Linux and Arch Linux ARM install and remove `.pkg.tar.zst`
packages. The workflow also checks AppImage extraction and runtime, application
unit and script tests, and a headless GUI and credential-store smoke test. These
checks do not replace an interactive desktop sign-in test.

## Install on Arch

Download the package for your CPU from [release-3.6.5-linux2](https://github.com/fluffy-furry/desktop/releases/tag/release-3.6.5-linux2),
then install it with `pacman -U`. For example, on x64:

```sh
sudo pacman -U ./GitHubDesktop-linux-x86_64-3.6.5-linux2.pkg.tar.zst
```

On Arch Linux ARM, use the `aarch64` package instead. Download newer releases
manually; this fork does not provide a pacman repository.

## Build locally

Use Docker on an x64 host. Replace `x64` with `arm64` for the cross-build:

```sh
target_arch=x64
docker build --platform linux/amd64 \
  --build-arg TARGET_ARCH="$target_arch" \
  --build-arg NODE_VERSION="$(cat .node-version)" \
  -t "desktop-linux-packaging:$target_arch" .github/actions/package-linux
docker run --rm --platform linux/amd64 \
  --mount "type=bind,source=$PWD,target=/github/workspace" \
  --workdir /github/workspace \
  -e GITHUB_ACTIONS=true -e "GITHUB_SHA=$(git rev-parse HEAD)" \
  "desktop-linux-packaging:$target_arch"
```

Use separate clean checkouts for x64 and ARM64 so target-specific dependencies
cannot mix. Docker writes packages to `dist/`.

## Test CI locally

Install `act` and use a Docker host. Run its package job for both targets before
pushing; run runtime jobs on machines with the matching CPU architecture:

```sh
act push -W .github/workflows/ci-linux.yml -j package \
  --matrix arch:x64 \
  -P ubuntu-24.04=ghcr.io/catthehacker/ubuntu:act-24.04 \
  --bind --artifact-server-path "${TMPDIR:-/tmp}/desktop-act-artifacts"
act push -W .github/workflows/ci-linux.yml -j package \
  --matrix arch:arm64 \
  -P ubuntu-24.04=ghcr.io/catthehacker/ubuntu:act-24.04 \
  --bind --artifact-server-path "${TMPDIR:-/tmp}/desktop-act-artifacts"
```

The release job publishes only after both native Linux test jobs pass. CI builds
all release files, creates the checksum manifest, uploads the files, and verifies
them before making the release public. No manual binary upload is part of this
workflow.

## Update from upstream

Run `bash script/sync-upstream.sh` from a clean `linux` checkout. It creates a
separate branch and merges the latest official stable tag. Resolve conflicts,
update package metadata, run local Docker and `act` checks, then merge and push.
The `development` branch remains an unmodified upstream mirror.
It includes upstream macOS, Windows and CodeQL workflows. Disable this fork's
GitHub Actions before updating that mirror, then re-enable Actions after the
push. The `linux` branch contains only its Linux workflow.
