#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
validator="${repo_root}/scripts/validate-main-release-version.sh"
fixture_directory="$(mktemp -d)"
trap 'rm -rf "${fixture_directory}"' EXIT

bash "${validator}"

released_fixture="${fixture_directory}/released.pbxproj"
cat >"${released_fixture}" <<'EOF'
MARKETING_VERSION = 1.3.0;
CURRENT_PROJECT_VERSION = 26081713;
EOF

if output="$(bash "${validator}" "${released_fixture}" 2>&1)"; then
	echo "FAIL: a version already tagged at another commit was accepted" >&2
	exit 1
fi
if [[ ${output} != *"current version v1.3.0+26081713 already belongs to"* ]]; then
	echo "FAIL: the version conflict was not identified" >&2
	echo "${output}" >&2
	exit 1
fi

echo "main release version tests passed"
