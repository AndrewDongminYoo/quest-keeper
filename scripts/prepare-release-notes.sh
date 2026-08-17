#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_file="${1:-${repo_root}/QuestKeeper.xcodeproj/project.pbxproj}"
release_root="${2:-${repo_root}/docs/releases}"
metadata_root="${3:-${repo_root}/fastlane/metadata}"

version_output="$(bash "${repo_root}/scripts/release-version.sh" "${project_file}")"
marketing_version="$(printf '%s\n' "${version_output}" | sed -n 's/^marketing_version=//p')"

# 리스팅 로캘 집합은 store-locales.sh가 소유한다.
# 여기서 다시 열거하면 validate-release-documents.sh와 갈라지고,
# 새 로캘이 한쪽에서만 검사되는 상태가 조용히 생긴다.
# 프로세스 치환은 생산자의 종료 상태를 감춘다. 발견이 실패하면 빈 목록으로
# 조용히 넘어가므로, 목록을 먼저 받아 상태를 확인한 뒤 순회한다.
locale_list="$(bash "${repo_root}/scripts/store-locales.sh" "${metadata_root}")"

locales=()
while IFS= read -r locale; do
	[[ -n ${locale} ]] || continue
	locales+=("${locale}")
done <<<"${locale_list}"

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
