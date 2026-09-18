#!/bin/sh
# Adapted from Shiftkey's RPM post script; preserve unrelated launchers.
set -e

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
