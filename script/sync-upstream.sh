#!/usr/bin/env bash
# Run from a clean Linux maintenance branch; preserves Linux patches via a merge.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

if [ -n "$(git status --porcelain)" ]; then
    echo 'Commit or stash local changes before syncing upstream.' >&2
    exit 1
fi

release_tag=${1:-$(gh api repos/desktop/desktop/releases/latest --jq .tag_name)}
if [[ ! "$release_tag" =~ ^release-[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Expected an upstream stable release tag; received: $release_tag" >&2
    exit 1
fi

git fetch --no-tags https://github.com/desktop/desktop.git "refs/tags/$release_tag:refs/tags/$release_tag"
if git merge-base --is-ancestor "$release_tag" HEAD; then
    echo "Already includes desktop/desktop $release_tag."
    exit 0
fi

git switch -c "sync/upstream-$release_tag"
if ! git merge --no-ff --no-edit "$release_tag"; then
    echo 'Resolve and commit the merge conflicts on this sync branch, then run Linux CI.' >&2
    exit 1
fi
printf 'Merged desktop/desktop %s. Run Linux CI before merging this branch.\n' "$release_tag"
