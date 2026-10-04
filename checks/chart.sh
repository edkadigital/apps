#!/usr/bin/env bash
# Checks the chart of one app: lints it, renders it, validates the result
# against the Kubernetes schemas and applies the community rules to it.
#
#   checks/chart.sh apps/gitea
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=checks/lib.sh
. "$here/lib.sh"

need helm yq jq kubeconform docker
app="$(app_dir "${1:-}")"
directory="$(basename "$app")"

slug="$(yq -r '.slug // ""' "$app/template.yaml")"
[ "$slug" = "$directory" ] || die "the slug \"$slug\" does not match the directory apps/$directory"

helm_values "$app"
chart="$(packed_chart "$app")"
rendered="$(mktemp)"
trap 'rm -rf "$chart" "$rendered"' EXIT

echo "== helm lint"
helm lint --strict "$chart" "${HELM_VALUES[@]}"

echo "== helm template"
helm template "$slug" "$chart" --namespace "smoke-$slug" "${HELM_VALUES[@]}" > "$rendered"

echo "== Kubernetes schemas"
# 1.32 is the oldest Kubernetes version an Edka cluster runs.
kubeconform -strict -summary -kubernetes-version 1.32.0 - < "$rendered"

echo "== community rules"
images="$(yq -o=json -I=0 '([.standard.image] | map(select(. != null))) + (.images // [])' "$app/template.yaml")"
findings="$(
  yq -o=json -I=0 ea '[.]' "$rendered" \
    | jq -r --argjson images "$images" --arg namespace "smoke-$slug" -f "$here/rendered.jq"
)"
if [ -n "$findings" ]; then
  echo "$findings"
  die "the chart of $slug breaks the community rules above"
fi

echo "== images"
"$here/images.sh" "$app" "$rendered"
echo "ok"
