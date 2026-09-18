# Build Linux ARM64

The [Linux build guide](linux-builds.md) shows the packaging commands. Set
`target_arch=arm64` on an x64 Docker host. The build uses an AArch64 GNU
cross-compiler, with x64 Node.js inside the container. No QEMU build is needed.

CI installs the resulting package on a native ARM64 runner, then runs unit,
script, GUI, credential-store and distribution checks. Keep x64 and ARM64
builds in separate checkouts so native dependencies do not mix.
