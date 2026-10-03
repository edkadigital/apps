#!/usr/bin/env bash
# Prints the apps a change touches, as a JSON list of directory names under
# apps/. A change outside apps/ touches every app, and so does a base commit
# that is not known.
#
#   checks/changed-apps.sh <base commit>
set -euo pipefail

base="${1:-}"
cd "$(git rev-parse --show-toplevel)"

all_apps() {
  local dir
  for dir in apps/*/; do
    [ -f "${dir}template.yaml" ] && basename "$dir"
  done
  return 0
}

if [ -z "$base" ] || ! git cat-file -e "$base^{commit}" 2>/dev/null; then
  names="$(all_apps)"
else
  changed="$(git diff --name-only "$base" HEAD)"
  if [ -n "$(printf '%s\n' "$changed" | grep -v '^apps/' | grep -v '\.md$' || true)" ]; then
    names="$(all_apps)"
  else
    names="$(printf '%s\n' "$changed" | grep '^apps/' | cut -d/ -f2 | sort -u || true)"
  fi
fi

apps=()
while IFS= read -r name; do
  [ -n "$name" ] || continue
  # An app that the change removed has nothing left to check.
  [ -f "apps/$name/template.yaml" ] || continue
  # The name ends up in commands. Anything but a slug stops here.
  [[ "$name" =~ ^[a-z][a-z0-9]*(-[a-z0-9]+)*$ ]] || {
    echo "error: apps/$name is not a slug: lowercase letters, digits and single hyphens" >&2
    exit 1
  }
  apps+=("$name")
done <<< "$names"

if [ "${#apps[@]}" -eq 0 ]; then
  echo "[]"
else
  printf '%s\n' "${apps[@]}" | jq -R . | jq -cs .
fi
