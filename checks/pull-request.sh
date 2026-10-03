#!/usr/bin/env bash
# Checks one app against the branch a pull request merges into: a change to a
# package raises its version, and the author of a new package is one of its
# maintainers.
#
#   checks/pull-request.sh apps/gitea <base commit> <GitHub login of the author>
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=checks/lib.sh
. "$here/lib.sh"

need git yq jq
app="$(app_dir "${1:-}")"
base="${2:-}"
author="${3:-}"
[ -n "$base" ] || die "name the commit the pull request merges into"
git cat-file -e "$base^{commit}" 2>/dev/null || die "the commit $base is not in this checkout"

slug="$(basename "$app")"
version="$(yq -r '.version // ""' "$app/template.yaml")"

if ! git cat-file -e "$base:$app/template.yaml" 2>/dev/null; then
  echo "== $slug is a new package"
  [ -n "$author" ] || die "name the GitHub login of the author"
  listed="$(yq -o=json -I=0 '[.maintainers[]?.github]' "$app/template.yaml")"
  if ! jq -en --argjson listed "$listed" --arg author "$author" \
    '$listed | map(ascii_downcase) | index($author | ascii_downcase)' >/dev/null; then
    die "$author opens the pull request and is not under maintainers in $app/template.yaml. A new package comes from one of its maintainers"
  fi
  echo "ok"
  exit 0
fi

if git diff --quiet "$base" HEAD -- "$app"; then
  echo "== $slug is unchanged"
  exit 0
fi

echo "== $slug changes"
# In format 1, version was the version of the app. Nothing in that format was
# ever listed, so there is no version to compare with.
if [ "$(git show "$base:$app/template.yaml" | yq -r '.format_version // 1')" != "2" ]; then
  echo "main has $slug in an older format"
  echo "ok"
  exit 0
fi
previous="$(git show "$base:$app/template.yaml" | yq -r '.version // ""')"
# sort -V orders versions. A version that sorts last and differs is higher.
highest="$(printf '%s\n%s\n' "$previous" "$version" | sort -V | tail -n 1)"
if [ "$version" = "$previous" ] || [ "$highest" != "$version" ]; then
  die "$slug changes and its version is $version, while main has $previous. A listed version never changes: raise version in template.yaml and chart/Chart.yaml"
fi
echo "version $previous -> $version"
echo "ok"
