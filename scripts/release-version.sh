#!/usr/bin/env bash

set -euo pipefail

project_file="${1:-QuestKeeper.xcodeproj/project.pbxproj}"

if [[ ! -f "$project_file" ]]; then
  echo "project file not found: $project_file" >&2
  exit 1
fi

read_unique_setting() {
  local setting_name="$1"
  local values
  local value_count

  values="$(
    sed -n \
      "s/^[[:space:]]*${setting_name}[[:space:]]*=[[:space:]]*\\([^;]*\\);.*/\\1/p" \
      "$project_file" |
      awk '{$1 = $1; print}' |
      sort -u
  )"
  value_count="$(printf '%s\n' "$values" | awk 'NF { count++ } END { print count + 0 }')"
  if [[ "$value_count" -ne 1 ]]; then
    echo "expected exactly one $setting_name value, found $value_count" >&2
    exit 1
  fi

  printf '%s' "$values"
}

marketing_version="$(read_unique_setting MARKETING_VERSION)"
build_number="$(read_unique_setting CURRENT_PROJECT_VERSION)"

if [[ ! "$marketing_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "MARKETING_VERSION must use X.Y.Z semantic versioning" >&2
  exit 1
fi
if [[ ! "$build_number" =~ ^[0-9]{8}$ ]]; then
  echo "CURRENT_PROJECT_VERSION must match YYMMDDHH" >&2
  exit 1
fi

tag="v$marketing_version+$build_number"
git check-ref-format "refs/tags/$tag"

printf 'marketing_version=%s\n' "$marketing_version"
printf 'build_number=%s\n' "$build_number"
printf 'tag=%s\n' "$tag"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    printf 'marketing_version=%s\n' "$marketing_version"
    printf 'build_number=%s\n' "$build_number"
    printf 'tag=%s\n' "$tag"
  } >>"$GITHUB_OUTPUT"
fi
