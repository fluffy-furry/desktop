#!/usr/bin/env bash
set -euo pipefail

executable=${1:?Usage: test-linux-smoke-retry.sh executable}
for title_bar in native custom; do
  for attempt in 1 2 3; do
    if output=$(DESKTOP_SMOKE_TITLE_BAR="$title_bar" node script/test-linux-smoke.cjs "$executable" 2>&1); then
      printf '%s\n' "$output"
      break
    fi
    printf '%s\n' "$output" >&2
    if [[ "$attempt" -eq 3 || "$output" != *'The secret was transferred or encrypted in an invalid way'* ]]; then
      exit 1
    fi
    # GNOME Keyring can cache a bad DH session; restart Node to negotiate anew.
    printf 'Retrying Secret Service smoke in a fresh process (%s/3)\n' "$((attempt + 1))" >&2
  done
done
