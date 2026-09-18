#!/bin/sh
# Adapted from Shiftkey's RPM preun script; retain the CLI during upgrades.
set -e

# RPM passes zero only when the last installed version is being removed.
if [ "${1:-1}" = 0 ] &&
    [ "$(readlink /usr/bin/github 2>/dev/null || :)" = /usr/lib/github-desktop/resources/app/static/github ]; then
    rm /usr/bin/github
fi
