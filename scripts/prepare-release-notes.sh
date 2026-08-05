#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_file="${1:-${repo_root}/QuestKeeper.xcodeproj/project.pbxproj}"
release_root="${2:-${repo_root}/docs/releases}"
metadata_file="${3:-${repo_root}/fastlane/metadata/ko/release_notes.txt}"

version_output="$(bash "${repo_root}/scripts/release-version.sh" "${project_file}")"
marketing_version="$(printf '%s\n' "${version_output}" | sed -n 's/^marketing_version=//p')"
source_file="${release_root}/${marketing_version}/ko.txt"

if [[ ! -f ${source_file} ]]; then
	previous_tag="$(git -C "${repo_root}" tag --list 'v*+*' --sort=-version:refname | sed -n '1p')"
	if [[ -z ${previous_tag} ]]; then
		echo "cannot draft release notes without a previous version tag" >&2
		exit 1
	fi
	commits="$(git -C "${repo_root}" log --no-merges --pretty=format:%s "${previous_tag}..HEAD")"
	notes=()

	if printf '%s\n' "${commits}" | grep -Eq '^(feat|fix)\(widget\):'; then
		notes+=("홈 화면 위젯의 가독성을 높이고 앱 화면과 일관된 몬스터 및 완료 아이콘을 적용했습니다.")
	fi
	if printf '%s\n' "${commits}" | grep -Eq '^fix\(security\):.*title'; then
		notes+=("지나치게 긴 퀘스트 제목이 화면과 저장 데이터에 영향을 주지 않도록 입력 처리를 강화했습니다.")
	fi
	if printf '%s\n' "${commits}" | grep -Eq '^fix\(security\):.*(widget|notification)'; then
		notes+=("알림과 위젯에서 퀘스트 정보를 더 안전하고 안정적으로 처리하도록 개선했습니다.")
	fi
	if [[ ${#notes[@]} -eq 0 ]] && printf '%s\n' "${commits}" | grep -Eq '^feat(\([^)]+\))?!?:'; then
		notes+=("새로운 기능과 사용 흐름을 추가했습니다.")
	fi
	if [[ ${#notes[@]} -eq 0 ]] && printf '%s\n' "${commits}" | grep -Eq '^(fix|perf)(\([^)]+\))?!?:'; then
		notes+=("앱의 안정성과 반응성을 개선했습니다.")
	fi
	if [[ ${#notes[@]} -eq 0 ]]; then
		echo "no user-facing commits found after ${previous_tag}" >&2
		exit 1
	fi

	mkdir -p "$(dirname "${source_file}")"
	{
		printf 'Quest Keeper %s\n\n' "${marketing_version}"
		for note in "${notes[@]}"; do
			printf '• %s\n' "${note}"
		done
	} >"${source_file}"
fi

if [[ ! -s ${source_file} ]]; then
	echo "release notes are empty: ${source_file}" >&2
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
