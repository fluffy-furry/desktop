#!/usr/bin/env bash
set -euo pipefail

# Test the installed release package against a distribution's actual libraries.
# Run on the matching architecture. For binfmt/QEMU, DESKTOP_TEST_NODE must point
# to a Node binary matching the target platform, not the host architecture.
package=$(realpath "${1:?Usage: test-linux-docker.sh package.deb image [linux/amd64|linux/arm64] [package.rpm]}")
image=${2:?A Docker distribution image is required}
platform=${3:-linux/amd64}
rpm_package=${4:-}
mounts=(--mount "type=bind,source=$package,target=/package.deb,readonly")
if [[ -n "$rpm_package" ]]; then
  rpm_package=$(realpath "$rpm_package")
  mounts+=(--mount "type=bind,source=$rpm_package,target=/package.rpm,readonly")
fi
repo=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$repo/dist"
# Keep Docker mounts inside the workspace so this also works with act --bind.
test_root=$(mktemp -d "$repo/dist/docker-smoke.XXXXXX")
trap 'rm -rf "$test_root"' EXIT
cp "${DESKTOP_TEST_NODE:-$(command -v node)}" "$test_root/node"
node_binary="$test_root/node"
payload="$test_root/payload"
dpkg-deb --extract "$package" "$payload"

docker run --rm --init --shm-size=1g --platform "$platform" \
  --cap-add IPC_LOCK \
  "${mounts[@]}" \
  --mount "type=bind,source=$payload,target=/payload,readonly" \
  --mount "type=bind,source=$repo,target=/repo,readonly" \
  --mount "type=bind,source=$node_binary,target=/usr/local/bin/node,readonly" \
  --env DEBIAN_FRONTEND=noninteractive \
  --env DESKTOP_TEST_PLATFORM="$platform" \
  --env DESKTOP_TEST_RPM="$([[ -n "$rpm_package" ]] && echo 1 || echo 0)" \
  --env DESKTOP_SMOKE_TIMEOUT="${DESKTOP_SMOKE_TIMEOUT:-45000}" \
  --workdir /repo "$image" bash -euo pipefail -c '
    cat /etc/os-release
    uname -m
    case "$DESKTOP_TEST_PLATFORM:$(node -p process.arch)" in
      linux/amd64:x64|linux/arm64:arm64) ;;
      *) printf "Set DESKTOP_TEST_NODE to a Node binary for %s\n" "$DESKTOP_TEST_PLATFORM" >&2; exit 1 ;;
    esac
    if command -v apt-get >/dev/null; then
      apt-get update
      apt-get install -y --no-install-recommends /package.deb xvfb xauth dbus-x11 desktop-file-utils python3
      bash script/test-linux-package.sh /package.deb
      executable=/usr/lib/github-desktop/github-desktop
    elif command -v dnf >/dev/null; then
      if [[ "$DESKTOP_TEST_RPM" == 1 ]]; then
        dnf install -y /package.rpm
        test -L /usr/bin/github
        executable=/usr/lib/github-desktop/github-desktop
      else
        executable=/payload/usr/lib/github-desktop/github-desktop
      fi
      dnf install -y gtk3 nss alsa-lib mesa-libgbm libXScrnSaver libsecret gnome-keyring xorg-x11-server-Xvfb xorg-x11-xauth dbus-daemon dbus-x11 dejavu-sans-fonts libcurl libnotify util-linux
    elif command -v zypper >/dev/null; then
      if [[ "$DESKTOP_TEST_RPM" == 1 ]]; then
        zypper --non-interactive --no-gpg-checks install --no-recommends /package.rpm
        test -L /usr/bin/github
        executable=/usr/lib/github-desktop/github-desktop
      else
        executable=/payload/usr/lib/github-desktop/github-desktop
      fi
      zypper --non-interactive install --no-recommends libgtk-3-0 mozilla-nss libasound2 libgbm1 libXss1 libsecret-1-0 gnome-keyring xvfb-run xorg-x11-server-Xvfb xauth dbus-1 dbus-1-daemon dbus-1-tools dejavu-fonts libcurl4 libnotify4 util-linux
    else
      printf "Unsupported distribution package manager\n" >&2
      exit 1
    fi
    # Use the installed RPM on Fedora/openSUSE when one was supplied.
    export executable
    ldd "$executable" | tee /tmp/desktop-libraries
    if grep -q "not found" /tmp/desktop-libraries; then
      printf "The distribution is missing an Electron runtime library\n" >&2
      exit 1
    fi
    resources="$(dirname "$executable")/resources/app"
    "$resources/git/bin/git" --version
    "$resources/static/github" --help
    test_data=$(mktemp -d)
    export XDG_DATA_HOME="$test_data/data"
    export XDG_RUNTIME_DIR="$test_data/runtime"
    mkdir -p "$XDG_DATA_HOME" "$XDG_RUNTIME_DIR"
    chmod 700 "$XDG_RUNTIME_DIR"
    xvfb-run -a dbus-run-session -- bash -euo pipefail -c '\''
      printf "temporary-ci-keyring-password" | gnome-keyring-daemon --unlock --components=secrets >/dev/null
      for title_bar in native custom; do
        DESKTOP_SMOKE_TITLE_BAR=$title_bar node script/test-linux-smoke.cjs "$executable"
      done
    '\''
    if command -v apt-get >/dev/null; then
      apt-get remove -y github-desktop
      test ! -L /usr/bin/github
      apt-get purge -y github-desktop
      printf "Distribution installation, GUI and removal checks passed.\n"
    elif [[ "$DESKTOP_TEST_RPM" == 1 ]]; then
      if command -v dnf >/dev/null; then
        dnf remove -y github-desktop
      else
        zypper --non-interactive remove github-desktop
      fi
      test ! -L /usr/bin/github
      printf "RPM installation, GUI and removal checks passed.\n"
    else
      printf "Distribution runtime checks passed.\n"
    fi
  '
