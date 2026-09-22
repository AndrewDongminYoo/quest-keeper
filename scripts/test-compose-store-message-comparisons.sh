#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_candidate_root="${repo_root}/fastlane/candidates/and-41"
work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT

mock_repo="${work_dir}/mock-repo"
candidate_root="${mock_repo}/fastlane/candidates/and-41"
raw_root="${candidate_root}/raw/ko"
output_root="${work_dir}/comparison"
fake_bin="${work_dir}/bin"
font_path="${work_dir}/StoreScreenshotFont.ttc"
oxipng_log="${work_dir}/oxipng.log"

mkdir -p \
	"${mock_repo}/scripts" \
	"${raw_root}" \
	"${candidate_root}/screenshots/ko" \
	"${candidate_root}/comparison/b/copy" \
	"${candidate_root}/comparison/c/copy" \
	"${mock_repo}/fastlane/screenshots/generated" \
	"${output_root}/cards/ko" \
	"${fake_bin}"

cp "${repo_root}/scripts/compose-store-screenshots.sh" "${mock_repo}/scripts/compose-store-screenshots.sh"
cp "${repo_root}/scripts/compose-store-message-comparisons.sh" "${mock_repo}/scripts/compose-store-message-comparisons.sh"
cp "${source_candidate_root}/comparison/b/copy/ko.txt" "${candidate_root}/comparison/b/copy/ko.txt"
cp "${source_candidate_root}/comparison/c/copy/ko.txt" "${candidate_root}/comparison/c/copy/ko.txt"

raw_names=(
	01-dungeon
	02-battle
	06-daily-grave
)

for raw_name in "${raw_names[@]}"; do
	printf 'raw %s\n' "${raw_name}" >"${raw_root}/iPhone 17 Pro Max-${raw_name}.png"
done

expected_names=(
	'iPhone 17 Pro Max-01-dungeon.png'
	'iPhone 17 Pro Max-02-battle.png'
	'iPhone 17 Pro Max-03-daily-grave.png'
)

for expected_name in "${expected_names[@]}"; do
	printf 'candidate a %s\n' "${expected_name}" >"${candidate_root}/screenshots/ko/${expected_name}"
done

cat >"${fake_bin}/magick" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
output="${!#}"
printf '%s\n' "$*" >"${output}"
SCRIPT
chmod +x "${fake_bin}/magick"
cat >"${fake_bin}/oxipng" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" >"${OXIPNG_LOG}"
SCRIPT
chmod +x "${fake_bin}/oxipng"
: >"${font_path}"
printf 'stale\n' >"${output_root}/cards/ko/stale.png"

STORE_SCREENSHOT_FONT_PATH="${font_path}" \
	OXIPNG_LOG="${oxipng_log}" \
	PATH="${fake_bin}:${PATH}" \
	bash "${mock_repo}/scripts/compose-store-message-comparisons.sh" "${output_root}"

if [[ ! -f ${oxipng_log} ]]; then
	echo "FAIL: comparison output was not optimized before hashing" >&2
	exit 1
fi
if [[ $(<"${oxipng_log}") != *'--strip'*'safe'* ]]; then
	echo "FAIL: comparison output omitted the repository PNG optimization contract" >&2
	exit 1
fi
optimized_png_count="$(tail -n +3 "${oxipng_log}" | wc -l)"
if [[ ${optimized_png_count} -ne 9 ]]; then
	echo "FAIL: comparison output optimized ${optimized_png_count} PNG files instead of 9" >&2
	exit 1
fi

card_files=("${output_root}/cards/ko"/*.png)
if [[ ${#card_files[@]} -ne 3 ]]; then
	echo "FAIL: comparison output retained ${#card_files[@]} participant cards instead of 3" >&2
	exit 1
fi

if [[ -e ${output_root}/cards/ko/stale.png ]]; then
	echo "FAIL: comparison output retained a stale participant card" >&2
	exit 1
fi

generated_manifest_count="$(wc -l <"${output_root}/manifest.sha256")"
if [[ ${generated_manifest_count} -ne 9 ]]; then
	echo "FAIL: generated comparison manifest does not contain exactly 9 assets" >&2
	exit 1
fi
(
	cd "${output_root}"
	shasum -a 256 -c manifest.sha256
)

candidate_b_contracts=(
	'01-dungeon|01-dungeon|할 일을|몬스터로 바꾸세요'
	'02-battle|02-battle|마감이 다가오면|몬스터가 성장'
	'03-daily-grave|06-daily-grave|완료하면|한 번에 처치'
)
candidate_c_contracts=(
	'01-dungeon|01-dungeon|계정 없이|바로 시작'
	'02-battle|02-battle|광고 없이|내 일에 집중'
	'03-daily-grave|06-daily-grave|기록은|기기 안에만'
)

for candidate in b c; do
	candidate_files=("${output_root}/screenshots/${candidate}/ko"/*.png)
	if [[ ${#candidate_files[@]} -ne 3 ]]; then
		echo "FAIL: candidate ${candidate} produced ${#candidate_files[@]} screenshots instead of 3" >&2
		exit 1
	fi

	if [[ ${candidate} == b ]]; then
		contracts=("${candidate_b_contracts[@]}")
	else
		contracts=("${candidate_c_contracts[@]}")
	fi

	for contract in "${contracts[@]}"; do
		IFS='|' read -r output_name source_name support_line headline <<<"${contract}"
		output_path="${output_root}/screenshots/${candidate}/ko/iPhone 17 Pro Max-${output_name}.png"
		render_command="$(<"${output_path}")"
		source_path="${raw_root}/iPhone 17 Pro Max-${source_name}.png"
		for expected_argument in "${source_path}" "${support_line}" "${headline}"; do
			if [[ ${render_command} != *"${expected_argument}"* ]]; then
				echo "FAIL: candidate ${candidate} ${output_name} omitted ${expected_argument}" >&2
				exit 1
			fi
		done
	done
done

for candidate in a b c; do
	card_path="${output_root}/cards/ko/candidate-${candidate}.png"
	if [[ ! -f ${card_path} ]]; then
		echo "FAIL: missing candidate ${candidate} participant card" >&2
		exit 1
	fi

	card_command="$(<"${card_path}")"
	if [[ ${candidate} == a ]]; then
		screenshot_root="${candidate_root}/screenshots/ko"
	else
		screenshot_root="${output_root}/screenshots/${candidate}/ko"
	fi
	first_path="${screenshot_root}/${expected_names[0]}"
	second_path="${screenshot_root}/${expected_names[1]}"
	third_path="${screenshot_root}/${expected_names[2]}"
	if [[ ${card_command} != *"${first_path}"*"${second_path}"*"${third_path}"* ]]; then
		echo "FAIL: candidate ${candidate} participant card changed the approved source order" >&2
		exit 1
	fi
	if [[ ${card_command} != *'-size 24x2868'*'+append'*'-strip -alpha off -depth 8 -define png:color-type=2'* ]]; then
		echo "FAIL: candidate ${candidate} participant card omitted the fixed spacer contract" >&2
		exit 1
	fi
done

persisted_root="${source_candidate_root}/comparison"
find "${persisted_root}" -type f -name '*.png' -print >"${work_dir}/persisted-pngs.txt"
persisted_png_count="$(wc -l <"${work_dir}/persisted-pngs.txt")"
if [[ ${persisted_png_count} -ne 9 ]]; then
	echo "FAIL: checked-in comparison set contains ${persisted_png_count} PNG files instead of 9" >&2
	exit 1
fi
persisted_manifest_count="$(wc -l <"${persisted_root}/manifest.sha256")"
if [[ ${persisted_manifest_count} -ne 9 ]]; then
	echo "FAIL: checked-in comparison manifest does not contain exactly 9 assets" >&2
	exit 1
fi
(
	cd "${persisted_root}"
	shasum -a 256 -c manifest.sha256
)

for candidate in b c; do
	for expected_name in "${expected_names[@]}"; do
		persisted_path="${persisted_root}/screenshots/${candidate}/ko/${expected_name}"
		persisted_width="$(/usr/bin/sips -g pixelWidth "${persisted_path}" | awk '/pixelWidth/ { print $2 }')"
		persisted_height="$(/usr/bin/sips -g pixelHeight "${persisted_path}" | awk '/pixelHeight/ { print $2 }')"
		if [[ ${persisted_width} != 1320 || ${persisted_height} != 2868 ]]; then
			echo "FAIL: checked-in candidate ${candidate} screenshot has invalid dimensions: ${expected_name}" >&2
			exit 1
		fi
	done
done

for candidate in a b c; do
	persisted_path="${persisted_root}/cards/ko/candidate-${candidate}.png"
	persisted_width="$(/usr/bin/sips -g pixelWidth "${persisted_path}" | awk '/pixelWidth/ { print $2 }')"
	persisted_height="$(/usr/bin/sips -g pixelHeight "${persisted_path}" | awk '/pixelHeight/ { print $2 }')"
	if [[ ${persisted_width} != 4008 || ${persisted_height} != 2868 ]]; then
		echo "FAIL: checked-in candidate ${candidate} card has invalid dimensions" >&2
		exit 1
	fi
done

if command -v magick >/dev/null 2>&1; then
	rebuilt_root="${work_dir}/rebuilt"
	bash "${repo_root}/scripts/compose-store-message-comparisons.sh" "${rebuilt_root}"
	if ! diff -u "${persisted_root}/manifest.sha256" "${rebuilt_root}/manifest.sha256"; then
		echo "FAIL: checked-in comparison assets differ from a clean regeneration" >&2
		exit 1
	fi
fi

echo "store message comparison card tests passed"
