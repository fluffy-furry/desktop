#!/usr/bin/env bash
set -euo pipefail

# Only the Linux workflow calls this script, after both package and test jobs.
repo=${GITHUB_REPOSITORY:?}
source_sha=${GITHUB_SHA:?}
input_dir=${1:-release-input}
version=$(node -p "require('./app/package.json').version")
tag="release-$version-linux1"
title="GitHub Desktop $version"
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
mkdir "$staging/files"

for arch in amd64 arm64; do
  source_dir="$input_dir/$arch"
  (cd "$source_dir" && sha256sum --check SHA256SUMS)
  if [[ "$arch" == amd64 ]]; then
    rpm_arch=x86_64
    appimage_arch=x64
  else
    rpm_arch=aarch64
    appimage_arch=arm64
  fi
  for file in \
    "GitHubDesktop-linux-$arch-$version-linux1.deb" \
    "GitHubDesktop-linux-$rpm_arch-$version-linux1.rpm" \
    "GitHubDesktop-linux-$appimage_arch-$version-linux1.AppImage"; do
    test -s "$source_dir/$file"
    cp "$source_dir/$file" "$staging/files/$file"
  done
  test "$(find "$source_dir" -maxdepth 1 -type f | wc -l)" -eq 4
done
test "$(find "$staging/files" -maxdepth 1 -type f | wc -l)" -eq 6
(cd "$staging/files" && sha256sum -- * > SHA256SUMS)

# act exercises the same artifact and checksum gate without publishing.
if [[ "${ACT:-}" == true ]]; then
  echo "Local release dry-run passed for $tag at $source_sha"
  exit 0
fi

upstream_tag="release-$version"
gh api "repos/desktop/desktop/releases/tags/$upstream_tag" > "$staging/upstream.json"
jq -e --arg title "$title" '.draft == false and .prerelease == false and .name == $title' \
  "$staging/upstream.json" >/dev/null
node - "$staging/upstream.json" "$staging/notes.md" <<'NODE'
const fs = require('fs')
const [source, destination] = process.argv.slice(2)
const { body } = JSON.parse(fs.readFileSync(source, 'utf8'))
const notes = body.replace(
  /(\[[^\]\n]*\]\([^\n)]*\)|^\[[^\]\n]+\]:[^\n]*|https?:\/\/\S+)|(^|[\s(])#(\d+)\b/gm,
  (match, link, before, number) =>
    link || `${before}[#${number}](https://github.com/desktop/desktop/issues/${number})`
)
fs.writeFileSync(destination, `${notes}\n`)
NODE
cat >> "$staging/notes.md" <<EOF

---

Linux x64 and ARM64 packages from this fork. All binaries and SHA256SUMS were built and uploaded by [Linux CI](https://github.com/$repo/actions/runs/$GITHUB_RUN_ID) from [$source_sha](https://github.com/$repo/commit/$source_sha), after native architecture and distribution tests. Linux support carries forward [Shiftkey's work](https://github.com/shiftkey/desktop). Install updates manually from this fork's releases.
EOF

# GitHub does not expose unpublished drafts through the tag endpoint.
release_id=$(gh api --paginate "repos/$repo/releases?per_page=100" |
  jq -r --arg tag "$tag" '.[] | select(.tag_name == $tag) | .id')
if [[ -n "$release_id" ]]; then
  gh api "repos/$repo/releases/$release_id" > "$staging/release.json"
  if jq -e '.draft == false' "$staging/release.json" >/dev/null; then
    jq -e --arg tag "$tag" --arg title "$title" \
      '.prerelease == false and .tag_name == $tag and .name == $title and
       .author.login == "github-actions[bot]" and
       (.target_commitish | test("^[0-9a-f]{40}$"))' \
      "$staging/release.json" >/dev/null
    published_sha=$(jq -r '.target_commitish' "$staging/release.json")
    gh api "repos/$repo/git/ref/tags/$tag" > "$staging/tag.json"
    jq -e --arg sha "$published_sha" \
      '.object.type == "commit" and .object.sha == $sha' \
      "$staging/tag.json" >/dev/null
    gh api "repos/$repo/releases/$release_id/assets?per_page=100" \
      > "$staging/assets.json"
    jq -e 'length == 7 and all(.[];
      .state == "uploaded" and .uploader.login == "github-actions[bot]" and
      (.digest | test("^sha256:[0-9a-f]{64}$")))' \
      "$staging/assets.json" >/dev/null
    expected_names=$(cd "$staging/files" && printf '%s\n' * | sort)
    actual_names=$(jq -r '.[].name' "$staging/assets.json" | sort)
    test "$actual_names" = "$expected_names"
    echo "Already published $tag; use a new Linux revision for another release."
    exit 0
  fi
fi

# GitHub ignores target_commitish when this tag already exists. Reject a tag
# pointing elsewhere before creating or publishing any draft release.
if gh api "repos/$repo/git/ref/tags/$tag" > "$staging/tag.json" \
  2> "$staging/tag-error"; then
  jq -e --arg sha "$source_sha" \
    '.object.type == "commit" and .object.sha == $sha' \
    "$staging/tag.json" >/dev/null
elif ! grep -q '(HTTP 404)' "$staging/tag-error"; then
  cat "$staging/tag-error" >&2
  exit 1
fi

if [[ -z "$release_id" ]]; then
  jq -n --arg tag "$tag" --arg sha "$source_sha" --arg title "$title" \
    --rawfile body "$staging/notes.md" \
    '{tag_name: $tag, target_commitish: $sha, name: $title, body: $body,
      draft: true, prerelease: false}' > "$staging/create.json"
  gh api --method POST "repos/$repo/releases" --input "$staging/create.json" \
    > "$staging/release.json"
  release_id=$(jq -r '.id' "$staging/release.json")
fi
[[ "$release_id" =~ ^[1-9][0-9]*$ ]]
gh api "repos/$repo/releases/$release_id" > "$staging/release.json"
jq -e --arg tag "$tag" --arg sha "$source_sha" --arg title "$title" \
  --rawfile body "$staging/notes.md" \
  '.draft == true and .prerelease == false and .tag_name == $tag and
   .target_commitish == $sha and .name == $title and .body == $body and
   .author.login == "github-actions[bot]"' "$staging/release.json" >/dev/null

assets_url="repos/$repo/releases/$release_id/assets?per_page=100"
validate_assets() {
  gh api "$assets_url" > "$staging/assets.json"
  jq -e --arg dir "$staging/files" '
    length <= 7 and ([.[].name] | unique | length) == length and
    all(.[]; . as $asset |
      ($asset.id | type == "number" and . > 0) and
      $asset.uploader.login == "github-actions[bot]" and
      ($asset.name | IN("SHA256SUMS",
        "GitHubDesktop-linux-amd64-" + env.VERSION + "-linux1.deb",
        "GitHubDesktop-linux-arm64-" + env.VERSION + "-linux1.deb",
        "GitHubDesktop-linux-x86_64-" + env.VERSION + "-linux1.rpm",
        "GitHubDesktop-linux-aarch64-" + env.VERSION + "-linux1.rpm",
        "GitHubDesktop-linux-x64-" + env.VERSION + "-linux1.AppImage",
        "GitHubDesktop-linux-arm64-" + env.VERSION + "-linux1.AppImage")) and
      ($asset.state == "uploaded" or
       ($asset.state == "starter" and $asset.digest == null)))
  ' "$staging/assets.json" >/dev/null
}
export VERSION="$version"
validate_assets
for file in "$staging/files"/*; do
  name=${file##*/}
  expected_digest="sha256:$(sha256sum "$file" | cut -d ' ' -f 1)"
  expected_size=$(stat -c %s "$file")
  for attempt in 1 2 3; do
    validate_assets
    asset=$(jq -c --arg name "$name" '.[] | select(.name == $name)' "$staging/assets.json")
    if [[ -n "$asset" ]]; then
      state=$(jq -r '.state' <<< "$asset")
      if [[ "$state" == uploaded ]]; then
        jq -e --arg digest "$expected_digest" --argjson size "$expected_size" \
          '.digest == $digest and .size == $size' <<< "$asset" >/dev/null
        break
      fi
      asset_id=$(jq -r '.id' <<< "$asset")
      gh api --method DELETE "repos/$repo/releases/assets/$asset_id" >/dev/null
    fi
    echo "CI uploading $name (attempt $attempt)"
    if timeout --signal=TERM --kill-after=30s 6m \
      gh release upload "$tag" "$file" --repo "$repo"; then
      continue
    fi
    if [[ "$attempt" -eq 3 ]]; then
      echo "GitHub rejected $name; draft remains private" >&2
      exit 1
    fi
    sleep 5
  done
  validate_assets
  jq -e --arg name "$name" --arg digest "$expected_digest" \
    --argjson size "$expected_size" \
    'any(.[]; .name == $name and .state == "uploaded" and
      .digest == $digest and .size == $size)' "$staging/assets.json" >/dev/null
done
validate_assets
test "$(jq length "$staging/assets.json")" -eq 7
gh api --method PATCH "repos/$repo/releases/$release_id" -F draft=false \
  > "$staging/published.json"
jq -e --arg tag "$tag" '.draft == false and .tag_name == $tag' \
  "$staging/published.json" >/dev/null
test "$(gh api "repos/$repo/git/ref/tags/$tag" --jq '.object.sha')" = "$source_sha"
echo "Published $tag with six CI-built Linux binaries and SHA256SUMS"
