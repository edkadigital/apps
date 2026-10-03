#!/usr/bin/env bash
# Checks the images of one app against their registries: each pinned tag still
# points at the pinned digest, and the image is published for every platform
# the package lists. Reads the images from a rendered chart.
#
#   checks/images.sh apps/gitea <rendered chart>
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=checks/lib.sh
. "$here/lib.sh"

need docker yq jq
app="$(app_dir "${1:-}")"
rendered="${2:-}"
[ -f "$rendered" ] || die "name the file that holds the rendered chart"

platforms="$(yq -o=json -I=0 '.platforms // []' "$app/template.yaml")"
images="$(
  yq -o=json -I=0 ea '[.]' "$rendered" \
    | jq -r '[.. | objects | select((.image | type) == "string") | .image] | unique | .[]'
)"

failed=0
while IFS= read -r image; do
  [ -n "$image" ] || continue
  reference="${image%@*}"
  pinned="${image##*@}"

  manifest="$(docker buildx imagetools inspect "$reference" --format '{{json .Manifest}}')" \
    || die "$reference is not in its registry"
  current="$(jq -r '.digest' <<< "$manifest")"
  if [ "$current" != "$pinned" ]; then
    echo "$reference points at $current, and the package pins $pinned"
    failed=1
    continue
  fi

  # An index lists one manifest per platform. A plain image is built for one.
  published="$(jq -c '[.manifests[]?.platform | select(.os != "unknown") | "\(.os)/\(.architecture)"]' <<< "$manifest")"
  if [ "$published" = "[]" ]; then
    published="$(docker buildx imagetools inspect "$image" --format '{{json .Image}}' | jq -c '["\(.os)/\(.architecture)"]')"
  fi
  missing="$(jq -rn --argjson want "$platforms" --argjson have "$published" '$want - $have | join(", ")')"
  if [ -n "$missing" ]; then
    echo "$reference is not published for $missing, which the package lists under platforms"
    failed=1
    continue
  fi
  echo "$reference: digest matches, published for $(jq -r 'join(", ")' <<< "$platforms")"
done <<< "$images"

[ "$failed" -eq 0 ] || die "the images of $(basename "$app") do not match what the package declares"
