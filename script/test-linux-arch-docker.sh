#!/usr/bin/env bash
set -euo pipefail

# Install and exercise the release package on Arch Linux or Arch Linux ARM.
# For binfmt/QEMU, DESKTOP_TEST_NODE must be a Node binary for the target arch.
package=$(realpath "${1:?Usage: test-linux-arch-docker.sh package.pkg.tar.zst image [linux/amd64|linux/arm64]}")
image=${2:?An Arch distribution image is required}
platform=${3:-linux/amd64}
test -f "$package"

repo=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$repo/dist"
# Keep nested Docker mounts inside the workspace for act --bind.
test_root=$(mktemp -d "$repo/dist/arch-smoke.XXXXXX")
trap 'rm -rf "$test_root"' EXIT
cp "${DESKTOP_TEST_NODE:-$(command -v node)}" "$test_root/node"

docker run --rm -i --init --shm-size=1g --platform "$platform" \
  --cap-add IPC_LOCK \
  --mount "type=bind,source=$package,target=/package.pkg.tar.zst,readonly" \
  --mount "type=bind,source=$repo,target=/repo,readonly" \
  --mount "type=bind,source=$test_root/node,target=/usr/local/bin/node,readonly" \
  --env DESKTOP_TEST_PLATFORM="$platform" \
  --env DESKTOP_SMOKE_TIMEOUT="${DESKTOP_SMOKE_TIMEOUT:-45000}" \
  --workdir /repo "$image" bash -euo pipefail -s <<'ARCH_SMOKE'
export LC_ALL=C
cat /etc/os-release
uname -m
case "$DESKTOP_TEST_PLATFORM:$(node -p process.arch)" in
  linux/amd64:x64) expected_arch=x86_64; node_arch=x64 ;;
  linux/arm64:arm64) expected_arch=aarch64; node_arch=arm64 ;;
  *) printf 'Set DESKTOP_TEST_NODE to a Node binary for %s\n' "$DESKTOP_TEST_PLATFORM" >&2; exit 1 ;;
esac
command -v pacman

package_info=$(pacman -Qip /package.pkg.tar.zst)
printf '%s\n' "$package_info"
package_arch=$(printf '%s\n' "$package_info" | awk -F: '/^Architecture[[:space:]]*:/ { gsub(/[[:space:]]/, "", $2); print $2 }')
test "$package_arch" = "$expected_arch"

# Fully update the rolling container before resolving the local package's deps.
pacman --noconfirm -Syu
pacman --noconfirm --needed -S xorg-server-xvfb xorg-xauth dbus ttf-dejavu
pacman --noconfirm -U /package.pkg.tar.zst
pacman -Q github-desktop-bin

executable=/usr/lib/github-desktop/github-desktop
resources=/usr/lib/github-desktop/resources/app
test -x "$executable"
test -L /usr/bin/github-desktop
test -L /usr/bin/github
test "$(readlink -f /usr/bin/github)" = "$resources/static/github"
test -f /usr/share/applications/github-desktop.desktop
node script/test-linux-elf.cjs "$node_arch" /usr/lib/github-desktop
ldd "$executable" | tee /tmp/desktop-libraries
if grep -q 'not found' /tmp/desktop-libraries; then
  printf 'Arch is missing an Electron runtime library\n' >&2
  exit 1
fi
"$resources/git/bin/git" --version
/usr/bin/github --help

test_data=$(mktemp -d)
export XDG_DATA_HOME="$test_data/data"
export XDG_RUNTIME_DIR="$test_data/runtime"
mkdir -p "$XDG_DATA_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
xvfb-run -a dbus-run-session -- bash -euo pipefail -c '
  printf "temporary-ci-keyring-password" | gnome-keyring-daemon --unlock --components=secrets >/dev/null
  bash script/test-linux-smoke-retry.sh /usr/lib/github-desktop/github-desktop
'

pacman --noconfirm -Rns github-desktop-bin
if pacman -Q github-desktop-bin >/dev/null 2>&1; then
  printf 'Arch package remains installed after removal\n' >&2
  exit 1
fi
test ! -e /usr/lib/github-desktop
test ! -e /usr/bin/github-desktop && test ! -L /usr/bin/github-desktop
test ! -e /usr/bin/github && test ! -L /usr/bin/github
printf 'Arch package installation, GUI and removal checks passed (%s).\n' "$expected_arch"
ARCH_SMOKE
