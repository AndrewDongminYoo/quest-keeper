#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
candidate_root="${repo_root}/fastlane/candidates/and-41"
raw_root="${candidate_root}/raw"
output_root="${1:-${candidate_root}/comparison}"
store_composer="${repo_root}/scripts/compose-store-screenshots.sh"
temporary_root="$(mktemp -d)"
trap 'rm -rf "${temporary_root}"' EXIT

if ! command -v magick >/dev/null 2>&1; then
	echo "ImageMagick is required to compose store message comparisons" >&2
	exit 1
fi
if ! command -v oxipng >/dev/null 2>&1; then
	echo "oxipng is required to optimize store message comparisons" >&2
	exit 1
fi

candidate_a_copy_root="${temporary_root}/copy-a"
candidate_a_output_root="${temporary_root}/comparison-a"
mkdir -p "${candidate_a_copy_root}"
head -n 3 "${candidate_root}/copy/ko.txt" >"${candidate_a_copy_root}/ko.txt"
STORE_SCREENSHOT_COPY_ROOT="${candidate_a_copy_root}" \
	STORE_SCREENSHOT_EXPECTED_COUNT=3 \
	bash "${store_composer}" \
	"${raw_root}" \
	"${candidate_a_output_root}" \
	ko

for candidate in b c; do
	STORE_SCREENSHOT_COPY_ROOT="${candidate_root}/comparison/${candidate}/copy" \
		STORE_SCREENSHOT_EXPECTED_COUNT=3 \
		bash "${store_composer}" \
		"${raw_root}" \
		"${output_root}/screenshots/${candidate}" \
		ko
done

cards_root="${output_root}/cards/ko"
mkdir -p "${cards_root}"
find "${cards_root}" -maxdepth 1 -type f -name '*.png' -delete

expected_names=(
	'iPhone 17 Pro Max-01-dungeon.png'
	'iPhone 17 Pro Max-02-battle.png'
	'iPhone 17 Pro Max-03-daily-grave.png'
)

for candidate in a b c; do
	if [[ ${candidate} == a ]]; then
		screenshot_root="${candidate_a_output_root}/ko"
	else
		screenshot_root="${output_root}/screenshots/${candidate}/ko"
	fi

	magick \
		"${screenshot_root}/${expected_names[0]}" \
		\( -size 24x2868 'xc:#24202b' \) \
		"${screenshot_root}/${expected_names[1]}" \
		\( -size 24x2868 'xc:#24202b' \) \
		"${screenshot_root}/${expected_names[2]}" \
		+append \
		-strip -alpha off -depth 8 -define png:color-type=2 \
		"${cards_root}/candidate-${candidate}.png"
done

output_pngs=(
	"${cards_root}/candidate-a.png"
	"${cards_root}/candidate-b.png"
	"${cards_root}/candidate-c.png"
	"${output_root}/screenshots/b/ko/${expected_names[0]}"
	"${output_root}/screenshots/b/ko/${expected_names[1]}"
	"${output_root}/screenshots/b/ko/${expected_names[2]}"
	"${output_root}/screenshots/c/ko/${expected_names[0]}"
	"${output_root}/screenshots/c/ko/${expected_names[1]}"
	"${output_root}/screenshots/c/ko/${expected_names[2]}"
)
oxipng --strip safe "${output_pngs[@]}"

manifest_path="${output_root}/manifest.sha256"
(
	cd "${output_root}"
	shasum -a 256 \
		cards/ko/candidate-a.png \
		cards/ko/candidate-b.png \
		cards/ko/candidate-c.png \
		screenshots/b/ko/'iPhone 17 Pro Max-01-dungeon.png' \
		screenshots/b/ko/'iPhone 17 Pro Max-02-battle.png' \
		screenshots/b/ko/'iPhone 17 Pro Max-03-daily-grave.png' \
		screenshots/c/ko/'iPhone 17 Pro Max-01-dungeon.png' \
		screenshots/c/ko/'iPhone 17 Pro Max-02-battle.png' \
		screenshots/c/ko/'iPhone 17 Pro Max-03-daily-grave.png'
) >"${manifest_path}.tmp"
mv "${manifest_path}.tmp" "${manifest_path}"

echo "composed 3 Korean store message comparison cards in ${cards_root}"
