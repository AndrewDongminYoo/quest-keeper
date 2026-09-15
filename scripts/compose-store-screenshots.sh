#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
candidate_root="${repo_root}/fastlane/candidates/and-41"
raw_root="${1:-${candidate_root}/raw}"
output_root="${2:-${candidate_root}/screenshots}"
copy_root="${STORE_SCREENSHOT_COPY_ROOT:-${candidate_root}/copy}"
font_path="${STORE_SCREENSHOT_FONT_PATH:-/System/Library/Fonts/AppleSDGothicNeo.ttc}"

if [[ $# -ge 3 ]]; then
	locales=("${@:3}")
else
	locales=(ko)
fi

output_parent="$(dirname "${output_root}")"
mkdir -p "${output_parent}"
normalized_output_parent="$(realpath "${output_parent}")"
output_basename="$(basename "${output_root}")"
normalized_output_root="${normalized_output_parent}/${output_basename}"
release_output_root="${repo_root}/fastlane/screenshots/generated"
release_output_parent="$(dirname "${release_output_root}")"
normalized_release_output_parent="$(realpath "${release_output_parent}")"
release_output_basename="$(basename "${release_output_root}")"
normalized_release_output_root="${normalized_release_output_parent}/${release_output_basename}"

if [[ ${normalized_output_root} == "${normalized_release_output_root}" ]]; then
	echo "candidate output must not use the release screenshot directory: ${output_root}" >&2
	exit 1
fi

if [[ ${raw_root} == "${output_root}" ]]; then
	echo "raw and generated screenshot roots must be different: ${raw_root}" >&2
	exit 1
fi

requires_korean_rendering=false
for locale in "${locales[@]}"; do
	if [[ ${locale} == ko ]]; then
		requires_korean_rendering=true
		break
	fi
done

if [[ ${requires_korean_rendering} == true ]]; then
	if ! command -v magick >/dev/null 2>&1; then
		echo "ImageMagick is required to compose store screenshots" >&2
		exit 1
	fi

	if [[ ! -f ${font_path} ]]; then
		echo "store screenshot font not found: ${font_path}" >&2
		exit 1
	fi
fi

temporary_root="$(mktemp -d)"
trap 'rm -rf "${temporary_root}"' EXIT
shopt -s nullglob

resolve_source() {
	local locale_directory="$1"
	local source_name="$2"
	local matches=()
	local direct_source="${locale_directory}/${source_name}.png"
	local matched_source

	if [[ -f ${direct_source} ]]; then
		matches+=("${direct_source}")
	fi
	for matched_source in "${locale_directory}"/*-"${source_name}.png"; do
		if [[ -f ${matched_source} ]]; then
			matches+=("${matched_source}")
		fi
	done

	if [[ ${#matches[@]} -ne 1 ]]; then
		echo "source screenshot not found: ${locale_directory}/${source_name}.png" >&2
		return 1
	fi

	printf '%s\n' "${matches[0]}"
}

output_filename() {
	local source_path="$1"
	local source_name="$2"
	local output_name="$3"
	local source_filename
	source_filename="$(basename "${source_path}")"

	if [[ ${source_filename} == *-"${source_name}.png" ]]; then
		printf '%s%s.png\n' "${source_filename%"${source_name}".png}" "${output_name}"
	else
		printf '%s.png\n' "${output_name}"
	fi
}

for locale in "${locales[@]}"; do
	raw_locale="${raw_root}/${locale}"
	generated_locale="${output_root}/${locale}"
	staged_locale="${temporary_root}/${locale}"

	if [[ ! -d ${raw_locale} ]]; then
		echo "raw screenshot locale directory not found: ${raw_locale}" >&2
		exit 1
	fi

	mkdir -p "${generated_locale}" "${staged_locale}"

	if [[ ${locale} == ko ]]; then
		copy_file="${copy_root}/ko.txt"
		if [[ ! -f ${copy_file} ]]; then
			echo "store screenshot copy file not found: ${copy_file}" >&2
			exit 1
		fi

		composed_count=0
		while IFS='|' read -r output_name source_name support_line headline; do
			if [[ -z ${output_name} || -z ${source_name} ]]; then
				echo "invalid store screenshot copy row: ${copy_file}" >&2
				exit 1
			fi

			source_path="$(resolve_source "${raw_locale}" "${source_name}")"
			filename="$(output_filename "${source_path}" "${source_name}" "${output_name}")"
			output_path="${staged_locale}/${filename}"

			if [[ -z ${support_line} && -z ${headline} ]]; then
				cp "${source_path}" "${output_path}"
			elif [[ -z ${support_line} || -z ${headline} ]]; then
				echo "both support line and headline are required for ${output_name}" >&2
				exit 1
			else
				magick \
					-size 1320x2868 "xc:#130f1a" \
					\( "${source_path}" -resize 1000x2173 -bordercolor "#4b5367" -border 4 \) \
					-gravity south -geometry +0+96 -composite \
					-font "${font_path}" -gravity north -fill "#fff8e9" -pointsize 64 -annotate +0+112 "${support_line}" \
					-fill "#f5b36d" -pointsize 92 -annotate +0+205 "${headline}" \
					-strip -alpha off -depth 8 -define png:color-type=2 \
					"${output_path}"
			fi

			composed_count=$((composed_count + 1))
		done <"${copy_file}"

		if [[ ${composed_count} -ne 6 ]]; then
			echo "expected 6 Korean store screenshot rows, found ${composed_count}" >&2
			exit 1
		fi
	else
		raw_files=("${raw_locale}"/*.png)
		if [[ ${#raw_files[@]} -eq 0 ]]; then
			echo "no raw screenshots found in ${raw_locale}" >&2
			exit 1
		fi
		cp "${raw_files[@]}" "${staged_locale}/"
	fi

	find "${generated_locale}" -maxdepth 1 -type f -name '*.png' -delete
	staged_files=("${staged_locale}"/*.png)
	if [[ ${#staged_files[@]} -eq 0 ]]; then
		echo "no composed screenshots found for ${locale}" >&2
		exit 1
	fi
	cp "${staged_files[@]}" "${generated_locale}/"
	echo "composed ${#staged_files[@]} ${locale} App Store screenshots in ${generated_locale}"
done
