#!/bin/sh
set -e

case "$1" in
    remove|purge|disappear)
        # Only remove our own link, and keep it during package upgrades.
        if [ "$(readlink /usr/bin/github 2>/dev/null || :)" = /usr/lib/github-desktop/resources/app/static/github ]; then
            rm /usr/bin/github
        fi
        ;;
    upgrade|failed-upgrade|abort-install|abort-upgrade)
        ;;
    *)
        echo "postrm called with unknown argument: $1" >&2
        exit 1
        ;;
esac
