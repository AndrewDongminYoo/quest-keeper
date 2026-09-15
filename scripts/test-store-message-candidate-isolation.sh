#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
candidate_root="${repo_root}/fastlane/candidates/and-41"
production_subtitle="${repo_root}/fastlane/metadata/ko/subtitle.txt"
candidate_subtitle="${candidate_root}/metadata/ko/subtitle.txt"
work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT

if [[ $(<"${production_subtitle}") != "할 일을 사냥하는 픽셀 RPG 투두" ]]; then
	echo "FAIL: the release subtitle contains the unapproved AND-41 candidate" >&2
	exit 1
fi

if [[ ! -f ${candidate_subtitle} ]] || [[ $(<"${candidate_subtitle}") != "죄책감 없이 다시 시작하는 픽셀 투두" ]]; then
	echo "FAIL: the AND-41 candidate subtitle is missing from its isolated path" >&2
	exit 1
fi

if grep -qF "fastlane/candidates/and-41" "${repo_root}/fastlane/Deliverfile"; then
	echo "FAIL: Deliverfile references the unapproved AND-41 candidate" >&2
	exit 1
fi

mock_repo="${work_dir}/mock-repo"
mock_raw="${mock_repo}/fastlane/candidates/and-41/raw"
mock_release="${mock_repo}/fastlane/screenshots/generated"
mock_copy="${mock_repo}/fastlane/candidates/and-41/copy"
mock_bin="${work_dir}/bin"
mkdir -p "${mock_repo}/scripts" "${mock_raw}/ko" "${mock_release}" "${mock_copy}" "${mock_bin}"
cp "${repo_root}/scripts/compose-store-screenshots.sh" "${mock_repo}/scripts/compose-store-screenshots.sh"
cp "${candidate_root}/copy/ko.txt" "${mock_copy}/ko.txt"
: >"${work_dir}/StoreScreenshotFont.ttc"

for source_name in 01-dungeon 02-battle 03-hero-appearance 06-daily-grave 07-quest-editor 08-empty-dungeon; do
	printf 'source\n' >"${mock_raw}/ko/${source_name}.png"
done

cat >"${mock_bin}/magick" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
output="${!#}"
printf 'composed\n' >"${output}"
SCRIPT
chmod +x "${mock_bin}/magick"

for forbidden_output in "${mock_release}" "${mock_release}/ko/.."; do
	set +e
	STORE_SCREENSHOT_FONT_PATH="${work_dir}/StoreScreenshotFont.ttc" \
		PATH="${mock_bin}:${PATH}" \
		bash "${mock_repo}/scripts/compose-store-screenshots.sh" "${mock_raw}" "${forbidden_output}" ko >"${work_dir}/composer.log" 2>&1
	command_exit=$?
	set -e

	if [[ ${command_exit} -eq 0 ]]; then
		echo "FAIL: the candidate composer accepted the release screenshot directory: ${forbidden_output}" >&2
		exit 1
	fi

	if ! grep -qF "candidate output must not use the release screenshot directory" "${work_dir}/composer.log"; then
		echo "FAIL: the candidate composer did not explain the release-path rejection" >&2
		cat "${work_dir}/composer.log" >&2
		exit 1
	fi
done

echo "store message candidate isolation tests passed"
