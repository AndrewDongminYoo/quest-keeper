#!/usr/bin/env bash

set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
validator="${repo_root}/scripts/validate-store-screenshots.sh"
reachability_validator="${repo_root}/scripts/validate-store-screenshot-reachability.sh"
store_test="${repo_root}/QuestKeeperUITests/StoreScreenshotUITests.swift"
work_dir="$(mktemp -d)" || {
	echo "FAIL: could not create a temporary directory" >&2
	exit 1
}
trap 'rm -rf "${work_dir}"' EXIT

fake_bin="${work_dir}/bin"
release_root="${work_dir}/release"
candidate_root="${work_dir}/candidate"
mkdir -p "${fake_bin}" "${release_root}/ko" "${release_root}/en-US" "${candidate_root}/ko"

cat >"${fake_bin}/magick" <<'SCRIPT'
#!/usr/bin/env bash
if [[ $1 == identify ]]; then
	printf '1320 2868 8 Undefined\n'
	exit 0
fi
exit 1
SCRIPT
chmod +x "${fake_bin}/magick"

candidate_ko_names=(
	01-dungeon
	02-battle
	03-daily-grave
	04-hero-appearance
	05-quest-editor
	06-empty-dungeon
)

release_names=(
	01-dungeon
	02-battle
	03-hero-appearance
	06-daily-grave
	07-quest-editor
	08-empty-dungeon
)

for name in "${release_names[@]}"; do
	: >"${release_root}/ko/${name}.png"
	: >"${release_root}/en-US/${name}.png"
done

for name in "${candidate_ko_names[@]}"; do
	: >"${candidate_root}/ko/${name}.png"
done

output_file="${work_dir}/output.log"
PATH="${fake_bin}:${PATH}" bash "${validator}" "${release_root}" ko en-US >"${output_file}" 2>&1
command_exit=$?

if [[ ${command_exit} -ne 0 ]]; then
	echo "FAIL: the release-reachable screenshot set was rejected" >&2
	cat "${output_file}" >&2
	exit 1
fi

if ! grep -qF "validated 6 ko App Store screenshots" "${output_file}"; then
	echo "FAIL: the validator did not report the six-screen Korean contract" >&2
	cat "${output_file}" >&2
	exit 1
fi

if ! grep -qF "validated 6 en-US App Store screenshots" "${output_file}"; then
	echo "FAIL: the validator did not report the six-screen English contract" >&2
	cat "${output_file}" >&2
	exit 1
fi

STORE_SCREENSHOT_PROFILE=and-41 PATH="${fake_bin}:${PATH}" \
	bash "${validator}" "${candidate_root}" ko >"${output_file}" 2>&1
command_exit=$?

if [[ ${command_exit} -ne 0 ]]; then
	echo "FAIL: the isolated AND-41 candidate set was rejected" >&2
	cat "${output_file}" >&2
	exit 1
fi

for forbidden_name in 04-focus-plan 05-focus-selection; do
	: >"${candidate_root}/ko/${forbidden_name}.png"
	set +e
	STORE_SCREENSHOT_PROFILE=and-41 PATH="${fake_bin}:${PATH}" \
		bash "${validator}" "${candidate_root}" ko >"${output_file}" 2>&1
	command_exit=$?
	set -e
	if [[ ${command_exit} -eq 0 ]]; then
		echo "FAIL: the validator accepted a non-release ${forbidden_name} screenshot" >&2
		cat "${output_file}" >&2
		exit 1
	fi
	rm "${candidate_root}/ko/${forbidden_name}.png"
done

if ! bash "${reachability_validator}" "${store_test}" >>"${output_file}" 2>&1; then
	echo "FAIL: the current screenshot test enables a DEBUG-only feature" >&2
	cat "${output_file}" >&2
	exit 1
fi

for forbidden_argument in -dailyFocusLoopEnabled -recoveryLoopVariant; do
	policy_fixture="${work_dir}/forbidden-store-test.swift"
	printf 'app.launchArguments = ["%s"]\n' "${forbidden_argument}" >"${policy_fixture}"
	set +e
	bash "${reachability_validator}" "${policy_fixture}" >"${output_file}" 2>&1
	command_exit=$?
	set -e
	if [[ ${command_exit} -eq 0 ]]; then
		echo "FAIL: the reachability gate accepted ${forbidden_argument}" >&2
		cat "${output_file}" >&2
		exit 1
	fi
	if ! grep -qF "DEBUG-only feature argument: ${forbidden_argument}" "${output_file}"; then
		echo "FAIL: the reachability gate did not identify ${forbidden_argument}" >&2
		cat "${output_file}" >&2
		exit 1
	fi
done

bash "${repo_root}/scripts/test-compose-store-screenshots.sh"
bash "${repo_root}/scripts/test-compose-store-message-comparisons.sh"
bash "${repo_root}/scripts/test-store-message-candidate-isolation.sh"

echo "store screenshot tests passed"
