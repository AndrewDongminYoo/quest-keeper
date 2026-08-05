#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
screenshot_root="${1:-${repo_root}/fastlane/screenshots/generated}"
locale_directory="${screenshot_root}/ko"

if ! command -v magick >/dev/null 2>&1; then
	echo "ImageMagick is required to process store screenshots" >&2
	exit 1
fi
if [[ ! -d ${locale_directory} ]]; then
	echo "screenshot locale directory not found: ${locale_directory}" >&2
	exit 1
fi

temporary_directory="$(mktemp -d)"
trap 'rm -rf "${temporary_directory}"' EXIT
file_list="${temporary_directory}/files.txt"
find "${locale_directory}" -maxdepth 1 -type f -name '*.png' -print | sort >"${file_list}"

processed_count=0
while IFS= read -r file; do
	filename="$(basename "${file}")"
	output="${temporary_directory}/${filename}"
	magick "${file}" -strip -alpha off -depth 8 -define png:color-type=2 "${output}"
	mv "${output}" "${file}"
	processed_count=$((processed_count + 1))
done <"${file_list}"

if [[ ${processed_count} -eq 0 ]]; then
	echo "no screenshots found in ${locale_directory}" >&2
	exit 1
fi

echo "processed ${processed_count} store screenshots in ${locale_directory}"
