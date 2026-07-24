#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script_path="$repo_root/scripts/release-version.sh"
fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

expect_failure() {
  local fixture_path="$1"
  local expected_message="$2"
  local output

  if output="$(bash "$script_path" "$fixture_path" 2>&1)"; then
    fail "expected release-version.sh to reject $fixture_path"
  fi
  [[ "$output" == *"$expected_message"* ]] || fail "missing error: $expected_message"
}

valid_fixture="$fixture_dir/valid.pbxproj"
cat >"$valid_fixture" <<'EOF'
MARKETING_VERSION = 1.0.0;
CURRENT_PROJECT_VERSION = 26072410;
MARKETING_VERSION = 1.0.0;
CURRENT_PROJECT_VERSION = 26072410;
EOF

valid_output="$(bash "$script_path" "$valid_fixture")" || fail "valid version fixture was rejected"
[[ "$valid_output" == *"marketing_version=1.0.0"* ]] || fail "marketing version output is missing"
[[ "$valid_output" == *"build_number=26072410"* ]] || fail "build number output is missing"
[[ "$valid_output" == *"tag=v1.0.0+26072410"* ]] || fail "tag output is missing"

conflicting_fixture="$fixture_dir/conflicting.pbxproj"
cat >"$conflicting_fixture" <<'EOF'
MARKETING_VERSION = 1.0.0;
MARKETING_VERSION = 1.1.0;
CURRENT_PROJECT_VERSION = 26072410;
EOF
expect_failure "$conflicting_fixture" "expected exactly one MARKETING_VERSION"

invalid_build_fixture="$fixture_dir/invalid-build.pbxproj"
cat >"$invalid_build_fixture" <<'EOF'
MARKETING_VERSION = 1.0.0;
CURRENT_PROJECT_VERSION = 1;
EOF
expect_failure "$invalid_build_fixture" "CURRENT_PROJECT_VERSION must match YYMMDDHH"

echo "release-version tests passed"
