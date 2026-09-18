#!/usr/bin/env bash
set -euo pipefail

package=${1:?Usage: test-linux-package.sh path/to/package.deb [amd64|arm64]}
expected_arch=${2:-$(dpkg --print-architecture)}
case "$expected_arch" in
    amd64|arm64) ;;
    *) printf 'Unsupported package architecture: %s\n' "$expected_arch" >&2; exit 1 ;;
esac
check_dir=$(mktemp -d)
trap 'rm -rf "$check_dir"' EXIT

dpkg-deb --extract "$package" "$check_dir"
dpkg-deb --control "$package" "$check_dir/control"
test "$(dpkg-deb --field "$package" Package)" = github-desktop
test "$(dpkg-deb --field "$package" Architecture)" = "$expected_arch"
test -x "$check_dir/usr/lib/github-desktop/github-desktop"
test -x "$check_dir/usr/lib/github-desktop/resources/app/static/github"
test -x "$check_dir/usr/lib/github-desktop/resources/app/git/bin/git"
test "$(stat -c %a "$check_dir/usr/lib/github-desktop/chrome-sandbox")" = 4755
test "$(readlink "$check_dir/usr/bin/github-desktop")" = ../lib/github-desktop/github-desktop

# Checking the package label alone would miss native dependencies accidentally
# copied from a different build machine (Electron, Git, keytar, or trampolines).
python3 - "$check_dir/usr/lib/github-desktop" "$expected_arch" <<'PY'
from pathlib import Path
import sys

expected_machine = {"amd64": 62, "arm64": 183}[sys.argv[2]]
checked = 0
for path in Path(sys.argv[1]).rglob("*"):
    if not path.is_file():
        continue
    with path.open("rb") as binary:
        header = binary.read(20)
    if header[:4] != b"\x7fELF":
        continue
    byte_order = "little" if header[5] == 1 else "big"
    machine = int.from_bytes(header[18:20], byte_order)
    if machine != expected_machine:
        raise SystemExit(f"Wrong ELF architecture ({machine}): {path}")
    checked += 1
if checked == 0:
    raise SystemExit("No ELF binaries found in the package")
print(f"Verified {checked} ELF binaries for {sys.argv[2]}")
PY

desktop_file="$check_dir/usr/share/applications/github-desktop.desktop"
desktop-file-validate "$desktop_file"
grep -Fx 'StartupWMClass=GitHub Desktop' "$desktop_file"
grep -F 'x-scheme-handler/x-github-desktop-dev-auth' "$desktop_file"
"$check_dir/usr/lib/github-desktop/resources/app/static/github" --help
"$check_dir/usr/lib/github-desktop/resources/app/git/bin/git" --version

# Exercise maintainer-script lifecycle behavior in a temporary prefix.
# These copies cannot change the host's /usr/bin or desktop caches.
for name in postinst postrm; do
    sed "s|/usr/|$check_dir/usr/|g" "$check_dir/control/$name" > "$check_dir/$name"
done
# Simulate the old Shiftkey postrm deleting the newly unpacked launcher.
rm "$check_dir/usr/bin/github-desktop"
sh "$check_dir/postinst" configure
test "$(readlink "$check_dir/usr/bin/github-desktop")" = ../lib/github-desktop/github-desktop
test -L "$check_dir/usr/bin/github"
sh "$check_dir/postrm" upgrade
test -L "$check_dir/usr/bin/github"
sh "$check_dir/postrm" remove
test ! -L "$check_dir/usr/bin/github"
sh "$check_dir/postrm" purge
ln -s /unrelated/github "$check_dir/usr/bin/github"
sh "$check_dir/postinst" configure
sh "$check_dir/postrm" remove
test "$(readlink "$check_dir/usr/bin/github")" = /unrelated/github
printf 'Debian package checks passed: %s\n' "$package"
