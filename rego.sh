#!/usr/bin/env bash
set -euo pipefail

command -v opa >/dev/null 2>&1 || {
  echo "opa not found, skipping tests"
  exit 0
}

for dir in */*/ ; do
  rego_dir="$dir/rego"
  template="$dir/template.yaml"
  rego_file="$rego_dir/src.rego"

  [ -d "$rego_dir" ] || continue
  [ -f "$rego_file" ] || continue
  [ -f "$template" ] || continue

  echo "Testing rego in $rego_dir"
  opa test -v "$rego_dir"

  echo "Injecting rego into $template"
  REGO="$(cat "$rego_file")"
  export REGO

  yq eval -i '.spec.targets[0].rego = strenv(REGO)' "$template"
done
