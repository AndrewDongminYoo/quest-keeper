#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
composer="${repo_root}/scripts/compose-store-screenshots.sh"
work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT

raw_root="${work_dir}/raw"
output_root="${work_dir}/generated"
copy_root="${repo_root}/fastlane/screenshots/copy"
fake_bin="${work_dir}/bin"
font_path="${work_dir}/StoreScreenshotFont.ttc"
magick_log="${work_dir}/magick.log"

mkdir -p "${raw_root}/ko" "${raw_root}/en-US" "${output_root}/ko" "${output_root}/en-US" "${fake_bin}"
: >"${font_path}"

raw_names=(
	01-dungeon
	02-battle
	03-hero-appearance
	06-daily-grave
	07-quest-editor
	08-empty-dungeon
)

for locale in ko en-US; do
	for name in "${raw_names[@]}"; do
		printf '%s/%s\n' "${locale}" "${name}" >"${raw_root}/${locale}/iPhone 17 Pro Max-${name}.png"
	done
done

cat >"${fake_bin}/magick" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
: "${QUESTKEEPER_MAGICK_LOG:?}"
printf '%s\n' "$*" >>"${QUESTKEEPER_MAGICK_LOG}"
output="${!#}"
printf 'composed\n' >"${output}"
SCRIPT
chmod +x "${fake_bin}/magick"

printf 'stale\n' >"${output_root}/ko/stale.png"
printf 'stale\n' >"${output_root}/en-US/stale.png"

QUESTKEEPER_MAGICK_LOG="${magick_log}" \
	STORE_SCREENSHOT_COPY_ROOT="${copy_root}" \
	STORE_SCREENSHOT_FONT_PATH="${font_path}" \
	PATH="${fake_bin}:${PATH}" \
	bash "${composer}" "${raw_root}" "${output_root}" ko en-US

ko_names=(
	01-dungeon
	02-battle
	03-daily-grave
	04-hero-appearance
	05-quest-editor
	06-empty-dungeon
)

for name in "${ko_names[@]}"; do
	if [[ ! -f ${output_root}/ko/iPhone\ 17\ Pro\ Max-${name}.png ]]; then
		echo "FAIL: missing composed Korean screenshot ${name}.png" >&2
		exit 1
	fi
done

if [[ -e ${output_root}/ko/stale.png ]]; then
	echo "FAIL: the composer retained a stale Korean screenshot" >&2
	exit 1
fi

for name in "${raw_names[@]}"; do
	if ! cmp -s "${raw_root}/en-US/iPhone 17 Pro Max-${name}.png" "${output_root}/en-US/iPhone 17 Pro Max-${name}.png"; then
		echo "FAIL: the composer changed the English ${name}.png screenshot" >&2
		exit 1
	fi
done

if [[ -e ${output_root}/en-US/stale.png ]]; then
	echo "FAIL: the composer retained a stale English screenshot" >&2
	exit 1
fi

render_contracts=(
	'01-dungeon|01-dungeon|밀린 할 일이 부담될 땐|오늘의 몬스터부터'
	'02-battle|02-battle|끝낸 할 일은|단칼에 처치'
	'03-daily-grave|06-daily-grave|놓쳐도 괜찮아요|내일 다시 도전'
)

for contract in "${render_contracts[@]}"; do
	IFS='|' read -r output_name source_name support_line headline <<<"${contract}"
	source_path="${raw_root}/ko/iPhone 17 Pro Max-${source_name}.png"
	output_filename="iPhone 17 Pro Max-${output_name}.png"
	render_command="$(grep -F -- "${source_path}" "${magick_log}" || true)"
	for expected_argument in "${output_filename}" "${support_line}" "${headline}"; do
		if [[ ${render_command} != *"${expected_argument}"* ]]; then
			echo "FAIL: ${output_name} did not render ${source_name} with approved copy: ${expected_argument}" >&2
			printf 'render command: %s\n' "${render_command}" >&2
			exit 1
		fi
	done
done

passthrough_contracts=(
	'04-hero-appearance|03-hero-appearance'
	'05-quest-editor|07-quest-editor'
	'06-empty-dungeon|08-empty-dungeon'
)

for contract in "${passthrough_contracts[@]}"; do
	IFS='|' read -r output_name source_name <<<"${contract}"
	if ! cmp -s \
		"${raw_root}/ko/iPhone 17 Pro Max-${source_name}.png" \
		"${output_root}/ko/iPhone 17 Pro Max-${output_name}.png"; then
		echo "FAIL: ${output_name} did not preserve the ${source_name} source pixels" >&2
		exit 1
	fi
done

mv "${raw_root}/ko/iPhone 17 Pro Max-06-daily-grave.png" "${work_dir}/missing-daily-grave.png"
set +e
QUESTKEEPER_MAGICK_LOG="${magick_log}" \
	STORE_SCREENSHOT_COPY_ROOT="${copy_root}" \
	STORE_SCREENSHOT_FONT_PATH="${font_path}" \
	PATH="${fake_bin}:${PATH}" \
	bash "${composer}" "${raw_root}" "${output_root}" ko en-US >"${work_dir}/missing.log" 2>&1
command_exit=$?
set -e

if [[ ${command_exit} -eq 0 ]]; then
	echo "FAIL: the composer accepted a missing daily-grave source" >&2
	exit 1
fi

if ! grep -qF -- "source screenshot not found: ${raw_root}/ko/06-daily-grave.png" "${work_dir}/missing.log"; then
	echo "FAIL: the composer did not identify the missing daily-grave source" >&2
	cat "${work_dir}/missing.log" >&2
	exit 1
fi

echo "store screenshot composition tests passed"
