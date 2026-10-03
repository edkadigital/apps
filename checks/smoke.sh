#!/usr/bin/env bash
# Installs the chart of one app on a cluster and waits for it to become ready.
# The namespace enforces the baseline Pod Security Standard, so a pod that
# needs more than that never starts.
#
#   kind create cluster --name edka-apps
#   checks/smoke.sh apps/gitea kind-edka-apps
#
# The second argument is the kubectl context to install on. It is required, so
# the check never lands on whatever cluster kubectl happens to point at. Use a
# cluster that can be thrown away. KEEP=1 leaves the namespace in place.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=checks/lib.sh
. "$here/lib.sh"

need helm kubectl yq
app="$(app_dir "${1:-}")"
context="${2:-}"
[ -n "$context" ] || die "name the kubectl context to install on, such as kind-edka-apps"
kubectl config get-contexts "$context" >/dev/null 2>&1 || die "kubectl has no context named $context"

slug="$(yq -r '.slug // ""' "$app/template.yaml")"
[ -n "$slug" ] || die "$app/template.yaml has no slug"
namespace="smoke-$slug"

helm_values "$app"

kube() {
  kubectl --context "$context" "$@"
}

finish() {
  local status=$?
  if [ "$status" -ne 0 ]; then
    echo "== the install of $slug failed. What the cluster reports:"
    kube get all --namespace "$namespace" || true
    kube get events --namespace "$namespace" --sort-by=.lastTimestamp | tail -n 40 || true
    kube describe pods --namespace "$namespace" || true
    local pod
    for pod in $(kube get pods --namespace "$namespace" --output name 2>/dev/null); do
      kube logs --namespace "$namespace" "$pod" --all-containers --prefix --tail=200 || true
    done
  fi
  if [ "${KEEP:-}" != "1" ]; then
    kube delete namespace "$namespace" --ignore-not-found --wait=false >/dev/null || true
  fi
  exit "$status"
}

echo "== namespace $namespace on $context"
kube create namespace "$namespace"
trap finish EXIT
kube label namespace "$namespace" pod-security.kubernetes.io/enforce=baseline

if [ -f "$app/chart/ci/prerequisites.yaml" ]; then
  echo "== prerequisites"
  kube apply --namespace "$namespace" --filename "$app/chart/ci/prerequisites.yaml"
fi

echo "== helm install"
helm install "$slug" "$app/chart" --kube-context "$context" --namespace "$namespace" \
  "${HELM_VALUES[@]}" --wait --timeout 5m

kube get pods --namespace "$namespace"
echo "ok"
