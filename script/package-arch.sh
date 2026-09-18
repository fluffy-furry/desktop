#!/usr/bin/env bash
# Repack the CI-built Debian payload with Arch's makepkg; never rebuild Electron.
set -euo pipefail

target_arch=${1:-${TARGET_ARCH:-x64}}
case "$target_arch" in
  x64) deb_arch=amd64; pacman_arch=x86_64 ;;
  arm64) deb_arch=arm64; pacman_arch=aarch64 ;;
  *) printf 'Unsupported target architecture: %s\n' "$target_arch" >&2; exit 1 ;;
esac

test "$(uname -m)" = x86_64
command -v makepkg >/dev/null
command -v bsdtar >/dev/null
command -v runuser >/dev/null
command -v zstd >/dev/null
test -f app/package.json
test -f LICENSE

version=$(sed -nE 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' app/package.json)
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  printf 'Expected a stable app version, got %s\n' "$version" >&2
  exit 1
}

shopt -s nullglob
debs=(dist/GitHubDesktop-linux-"$deb_arch"-"$version"-linux*.deb)
test "${#debs[@]}" -eq 1 || {
  printf 'Expected exactly one %s Debian package, found %s\n' "$deb_arch" "${#debs[@]}" >&2
  exit 1
}
deb=${debs[0]}
test "$(ar t "$deb" | tail -n 1)" = data.tar.zst
control=$(ar p "$deb" control.tar.zst | bsdtar -xOf - ./control)
test "$(printf '%s\n' "$control" | sed -n 's/^Architecture: //p')" = "$deb_arch"
[[ "$(printf '%s\n' "$control" | sed -n 's/^Version: //p')" =~ ^$version-linux[0-9]+$ ]]

build_dir=$(mktemp -d)
trap 'rm -rf "$build_dir"' EXIT
mkdir -p "$build_dir/packages"
cp script/resources/arch/PKGBUILD script/resources/arch/github-desktop.install "$build_dir/"
cp "$deb" "$build_dir/github-desktop.deb"
cp LICENSE "$build_dir/LICENSE"
cp /etc/makepkg.conf "$build_dir/makepkg.conf"
printf '\nCARCH=%s\nPKGEXT=.pkg.tar.zst\nCOMPRESSZST=(zstd -c -T0 -)\nMAKEFLAGS="-j%s"\nPACKAGER="fluffy-furry <fluffy-furry@users.noreply.github.com>"\n' \
  "$pacman_arch" "$(nproc)" >> "$build_dir/makepkg.conf"
chown -R nobody:nobody "$build_dir"

export DESKTOP_ARCH_VERSION="$version"
export DESKTOP_DEB_SHA256="$(sha256sum "$deb" | cut -d ' ' -f 1)"
export DESKTOP_LICENSE_SHA256="$(sha256sum LICENSE | cut -d ' ' -f 1)"
(
  cd "$build_dir"
  runuser -u nobody -- env \
    HOME="$build_dir" \
    DESKTOP_ARCH_VERSION="$DESKTOP_ARCH_VERSION" \
    DESKTOP_DEB_SHA256="$DESKTOP_DEB_SHA256" \
    DESKTOP_LICENSE_SHA256="$DESKTOP_LICENSE_SHA256" \
    PKGDEST="$build_dir/packages" \
    makepkg --config "$build_dir/makepkg.conf" --nodeps --noconfirm --force
)

package="$build_dir/packages/github-desktop-bin-$version-2-$pacman_arch.pkg.tar.zst"
test -s "$package"
destination="dist/GitHubDesktop-linux-$pacman_arch-$version-linux2.pkg.tar.zst"
cp "$package" "$destination"
chown "$(stat -c '%u:%g' dist)" "$destination"
printf 'Arch package created at %s\n' "$destination"
