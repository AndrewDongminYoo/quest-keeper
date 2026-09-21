#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "${script_dir}/../.." && pwd -P)"

canonicalize_path() {
	local candidate_path="$1"
	local parent_path
	local resolved_parent

	if [[ -e ${candidate_path} || -L ${candidate_path} ]]; then
		/bin/realpath "${candidate_path}"
		return
	fi

	parent_path="$(dirname -- "${candidate_path}")"
	resolved_parent="$(/bin/realpath "${parent_path}")"
	printf '%s/%s\n' "${resolved_parent%/}" "$(basename -- "${candidate_path}")"
}

if [[ $# -ne 1 || $1 != "--check-availability" ]]; then
	if [[ $# -ne 4 || $1 != "--input" || $3 != "--output" ]]; then
		echo "usage: run.sh --check-availability | --input <absolute-path> --output <absolute-path>" >&2
		exit 1
	fi
	if [[ $2 != /* || $4 != /* ]]; then
		echo "input and output paths must be absolute" >&2
		exit 1
	fi

	canonical_input="$(canonicalize_path "$2")"
	canonical_output="$(canonicalize_path "$4")"
	if [[ ${canonical_input} == "${repo_root}" ||
		${canonical_input} == "${repo_root}/"* ||
		${canonical_output} == "${repo_root}" ||
		${canonical_output} == "${repo_root}/"* ]]; then
		echo "input and output paths must resolve outside the repository" >&2
		exit 1
	fi
fi

build_dir="$(mktemp -d)"
trap 'rm -rf "${build_dir}"' EXIT

xcrun swiftc \
	-swift-version 6 \
	-parse-as-library \
	-O \
	-framework FoundationModels \
	-o "${build_dir}/spike-116" \
	"${script_dir}/main.swift"

"${build_dir}/spike-116" "$@"
