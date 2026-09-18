#!/bin/sh
set -e

case "$1" in
    configure)
        # Shiftkey 3.4.x's old postrm removes this packaged link during upgrade.
        # Restore it after unpacking, while preserving unrelated executables.
        if [ ! -e /usr/bin/github-desktop ] && [ ! -L /usr/bin/github-desktop ]; then
            ln -s ../lib/github-desktop/github-desktop /usr/bin/github-desktop
        fi
        CLI_PATH=/usr/lib/github-desktop/resources/app/static/github
        if [ ! -e /usr/bin/github ] && [ ! -L /usr/bin/github ]; then
            ln -s "$CLI_PATH" /usr/bin/github
        fi
        if command -v update-desktop-database >/dev/null 2>&1; then
            update-desktop-database -q /usr/share/applications || :
        fi
        if command -v gtk-update-icon-cache >/dev/null 2>&1; then
            gtk-update-icon-cache -q -f /usr/share/icons/hicolor || :
        fi
        ;;
    abort-upgrade|abort-remove|abort-deconfigure)
        ;;
    *)
        echo "postinst called with unknown argument: $1" >&2
        exit 1
        ;;
esac
