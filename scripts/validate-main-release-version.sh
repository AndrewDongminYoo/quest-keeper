#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_file="${1:-${repo_root}/QuestKeeper.xcodeproj/project.pbxproj}"
version_output="$(bash "${repo_root}/scripts/release-version.sh" "${project_file}")"
tag="$(printf '%s\n' "${version_output}" | sed -n 's/^tag=//p')"

if ! git -C "${repo_root}" rev-parse --verify --quiet "refs/tags/${tag}" >/dev/null; then
	echo "release tag does not exist yet: ${tag}"
	exit 0
fi

tagged_commit="$(git -C "${repo_root}" rev-list -n 1 "${tag}")"
head_commit="$(git -C "${repo_root}" rev-parse HEAD)"
if [[ ${tagged_commit} != "${head_commit}" ]]; then
	echo "current version ${tag} already belongs to ${tagged_commit}, not HEAD ${head_commit}" >&2
	exit 1
fi

echo "current HEAD matches existing release tag ${tag}"
