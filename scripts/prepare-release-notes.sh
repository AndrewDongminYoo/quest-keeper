#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_file="${1:-${repo_root}/QuestKeeper.xcodeproj/project.pbxproj}"
release_root="${2:-${repo_root}/docs/releases}"
metadata_file="${3:-${repo_root}/fastlane/metadata/ko/release_notes.txt}"

version_output="$(bash "${repo_root}/scripts/release-version.sh" "${project_file}")"
marketing_version="$(printf '%s\n' "${version_output}" | sed -n 's/^marketing_version=//p')"
source_file="${release_root}/${marketing_version}/ko.txt"

if [[ ! -s ${source_file} ]]; then
	echo "write the release notes first: ${source_file}" >&2
	exit 1
fi

character_count="$(LC_ALL=en_US.UTF-8 wc -m <"${source_file}" | tr -d '[:space:]')"
if [[ ${character_count} -gt 4000 ]]; then
	echo "release notes exceed the App Store 4000-character limit: ${character_count}" >&2
	exit 1
fi

mkdir -p "$(dirname "${metadata_file}")"
cp "${source_file}" "${metadata_file}"
echo "prepared ${metadata_file} from ${source_file} (${character_count} characters)"
