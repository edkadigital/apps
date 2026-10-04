# Shared by the checks in this directory. Sourced, not run.

die() {
  echo "error: $*" >&2
  exit 1
}

need() {
  local tool
  for tool in "$@"; do
    command -v "$tool" >/dev/null 2>&1 || die "$tool is not installed"
  done
}

# The directory of one app, without a trailing slash.
app_dir() {
  local dir="${1:-}"
  [ -n "$dir" ] || die "name an app directory, such as apps/gitea"
  dir="${dir%/}"
  [ -f "$dir/template.yaml" ] || die "$dir has no template.yaml"
  [ -f "$dir/chart/Chart.yaml" ] || die "$dir has no chart/Chart.yaml"
  echo "$dir"
}

# The image tags the form pins, one "value.path=tag" per line. They come from
# standard.tag and from the auto_update targets of template.yaml with the
# default of the field each target names, so the checks run the images an
# install through Edka runs.
pinned_tags() {
  yq -r '
    . as $package
    | (
        ([$package.standard.tag] | map(select(. != null) | "image.tag=" + .))
        + [
          ($package.auto_update.targets // [])[]
          | select(.type == "image-tag" and .helm_value_path != null)
          | . as $target
          | ([($package.inputs_schema // {})[][] | select(.name == $target.field) | .config.default] | .[0]) as $tag
          | select($tag != null and $tag != "")
          | $target.helm_value_path + "=" + $tag
        ]
      )[]
  ' "$1/template.yaml"
}

# A copy of the chart of one app, named and versioned the way Edka packs it:
# with the slug and the version in template.yaml. Prints the directory of the
# copy. The caller removes it.
packed_chart() {
  local app="$1" copy
  copy="$(mktemp -d)"
  cp -R "$app/chart/." "$copy/"
  NAME="$(yq -r '.slug' "$app/template.yaml")" VERSION="$(yq -r '.version' "$app/template.yaml")" \
    yq -i '.name = strenv(NAME) | .version = strenv(VERSION)' "$copy/Chart.yaml"
  echo "$copy"
}

# Fills HELM_VALUES with the arguments every check passes to Helm.
helm_values() {
  local app="$1" pin
  HELM_VALUES=()
  if [ -f "$app/chart/ci/test-values.yaml" ]; then
    HELM_VALUES+=(--values "$app/chart/ci/test-values.yaml")
  fi
  while IFS= read -r pin; do
    [ -n "$pin" ] && HELM_VALUES+=(--set-string "$pin")
  done < <(pinned_tags "$app")
  return 0
}
