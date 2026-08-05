#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
screenshot_root="${1:-${repo_root}/fastlane/screenshots/generated}"
locale_directory="${screenshot_root}/ko"

if ! command -v magick >/dev/null 2>&1; then
	echo "ImageMagick is required to validate store screenshots" >&2
	exit 1
fi
if [[ ! -d ${locale_directory} ]]; then
	echo "screenshot locale directory not found: ${locale_directory}" >&2
	exit 1
fi

files=()
file_list="$(mktemp)"
trap 'rm -f "${file_list}"' EXIT
find "${locale_directory}" -maxdepth 1 -type f -name '*.png' -print | sort >"${file_list}"
while IFS= read -r file; do
	files+=("${file}")
done <"${file_list}"

if [[ ${#files[@]} -ne 6 ]]; then
	echo "expected 6 Korean screenshots, found ${#files[@]}" >&2
	exit 1
fi

for expected in 01-dungeon 02-focus-plan 03-focus-selection 04-daily-grave 05-quest-editor 06-empty-dungeon; do
	if ! printf '%s\n' "${files[@]}" | grep -q -- "${expected}"; then
		echo "missing screenshot: ${expected}" >&2
		exit 1
	fi
done

for file in "${files[@]}"; do
	image_metadata="$(magick identify -format '%w %h %z %A' "${file}")"
	read -r width height depth alpha_state <<<"${image_metadata}"
	case "${width}x${height}" in
	1260x2736 | 1290x2796 | 1320x2868) ;;
	*)
		echo "unsupported App Store screenshot size: ${width}x${height} (${file})" >&2
		exit 1
		;;
	esac
	if [[ ${alpha_state} != Undefined ]]; then
		echo "screenshot must not contain an alpha channel: ${file}" >&2
		exit 1
	fi
	if [[ ${depth} != 8 ]]; then
		echo "screenshot must use 8-bit channels: ${file}" >&2
		exit 1
	fi
done

echo "validated 6 Korean App Store screenshots in ${locale_directory}"
