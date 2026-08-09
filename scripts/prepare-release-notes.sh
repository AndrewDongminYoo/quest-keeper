#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_file="${1:-${repo_root}/QuestKeeper.xcodeproj/project.pbxproj}"
release_root="${2:-${repo_root}/docs/releases}"
metadata_root="${3:-${repo_root}/fastlane/metadata}"

version_output="$(bash "${repo_root}/scripts/release-version.sh" "${project_file}")"
marketing_version="$(printf '%s\n' "${version_output}" | sed -n 's/^marketing_version=//p')"

# deliver가 리스팅 로캘로 취급하는 디렉터리는 name.txt를 가진 것뿐이다.
# 로캘을 여기 나열하지 않고 메타데이터에서 읽어야 새 로캘이 조용히 누락되지 않는다.
locales=()
for candidate in "${metadata_root}"/*/; do
	[[ -f "${candidate}name.txt" ]] || continue
	locales+=("$(basename "${candidate}")")
done

if [[ ${#locales[@]} -eq 0 ]]; then
	echo "no listing locale found under ${metadata_root}" >&2
	exit 1
fi

for locale in "${locales[@]}"; do
	source_file="${release_root}/${marketing_version}/${locale}.txt"
	if [[ ! -s ${source_file} ]]; then
		echo "write the release notes first: ${source_file}" >&2
		exit 1
	fi

	character_count="$(LC_ALL=en_US.UTF-8 wc -m <"${source_file}" | tr -d '[:space:]')"
	if [[ ${character_count} -gt 4000 ]]; then
		echo "release notes exceed the App Store 4000-character limit: ${character_count} (${source_file})" >&2
		exit 1
	fi

	metadata_file="${metadata_root}/${locale}/release_notes.txt"
	cp "${source_file}" "${metadata_file}"
	echo "prepared ${metadata_file} from ${source_file} (${character_count} characters)"
done
