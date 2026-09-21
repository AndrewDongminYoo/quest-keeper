#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
runner="${repo_root}/scripts/spike-116/run.sh"

fail() {
	echo "FAIL: $1" >&2
	exit 1
}

[[ -f ${runner} ]] || fail "spike-116 runner is missing: ${runner}"

fixture_dir="$(mktemp -d)"
trap 'rm -rf "${fixture_dir}"' EXIT

availability_output="$(bash "${runner}" --check-availability)" || fail "availability check failed"
if ! printf '%s' "${availability_output}" | /usr/bin/python3 -c '
import json
import sys

payload = json.load(sys.stdin)
if not isinstance(payload, dict):
    raise SystemExit("availability response must be a JSON object")

availability = payload.get("modelAvailability")
if not isinstance(availability, (bool, str)) or availability == "":
    raise SystemExit("modelAvailability must be a boolean or non-empty string")

if not isinstance(payload.get("supportsKorean"), bool):
    raise SystemExit("supportsKorean must be a boolean")

context_size = payload.get("contextSize")
if not isinstance(context_size, int) or isinstance(context_size, bool) or context_size <= 0:
    raise SystemExit("contextSize must be a positive integer")
'; then
	fail "availability check did not return the required structured JSON"
fi

invalid_input="${fixture_dir}/nineteen-titles.txt"
result_path="${fixture_dir}/results.json"
for title_number in {1..19}; do
	printf 'private title %02d\n' "${title_number}" >>"${invalid_input}"
done
printf '\n' >>"${invalid_input}"

set +e
invalid_output="$(bash "${runner}" --input "${invalid_input}" --output "${result_path}" 2>&1)"
command_exit=$?
set -e

[[ ${command_exit} -ne 0 ]] || fail "runner accepted fewer than 20 non-empty titles"
[[ ${invalid_output} == *"expected exactly 20 non-empty titles, got 19"* ]] || {
	printf '%s\n' "${invalid_output}" >&2
	fail "runner did not reject the invalid count before model generation"
}
[[ ! -e ${result_path} ]] || fail "runner wrote a result for an invalid title count"

privacy_error="input and output paths must resolve outside the repository"
missing_developer_dir="${fixture_dir}/missing-xcode"

expect_private_paths_rejected() {
	local label="$1"
	local input_path="$2"
	local output_path="$3"
	local rejection_output
	local rejection_exit

	set +e
	rejection_output="$(DEVELOPER_DIR="${missing_developer_dir}" bash "${runner}" --input "${input_path}" --output "${output_path}" 2>&1)"
	rejection_exit=$?
	set -e

	[[ ${rejection_exit} -ne 0 ]] || fail "runner accepted ${label}"
	[[ ${rejection_output} == *"${privacy_error}"* ]] || {
		printf '%s\n' "${rejection_output}" >&2
		fail "runner did not enforce the outside-repository path requirement for ${label}"
	}
}

repository_input="${repo_root}/README.md"
expect_private_paths_rejected \
	"a repository-contained input path" \
	"${repository_input}" \
	"${fixture_dir}/direct-input-result.json"

repository_output="${repo_root}/scripts/spike-116/privacy-probe-results.json"
[[ ! -e ${repository_output} ]] || fail "repository output probe already exists: ${repository_output}"
expect_private_paths_rejected \
	"a repository-contained output path" \
	"${invalid_input}" \
	"${repository_output}"
[[ ! -e ${repository_output} ]] || fail "runner created a repository-contained output file"

linked_input="${fixture_dir}/repository-input-link.txt"
ln -s "${repository_input}" "${linked_input}"
expect_private_paths_rejected \
	"a symlink resolving to a repository-contained input" \
	"${linked_input}" \
	"${fixture_dir}/symlink-input-result.json"

failure_test_binary="${fixture_dir}/generation-failure-test"
xcrun swiftc \
	-D SPIKE_116_TESTS \
	-swift-version 6 \
	-parse-as-library \
	-framework FoundationModels \
	-o "${failure_test_binary}" \
	"${repo_root}/scripts/spike-116/main.swift" \
	"${repo_root}/scripts/spike-116/test-generation-failure.swift"
"${failure_test_binary}"

echo "spike-116 tests passed"
