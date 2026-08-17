#!/usr/bin/env bash

# Exercises validate-release-documents.sh against the real CHANGELOG and
# against copies with one fact broken at a time.
#
# Never invoke the script from an `if` or `&&` condition: bash disables `set -e`
# inside a condition context, so the early checks stop aborting and only the
# last line's status survives. An earlier draft of this harness did exactly
# that and reported three broken fixtures as passing.

set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script_path="${repo_root}/scripts/validate-release-documents.sh"
work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT

version_output="$(bash "${repo_root}/scripts/release-version.sh")"
version="$(printf '%s\n' "${version_output}" | sed -n 's/^marketing_version=//p')"
tag="$(printf '%s\n' "${version_output}" | sed -n 's/^tag=//p')"

failed=0

run_case() {
	local label="$1" fixture="$2" want="$3" status got

	bash "${script_path}" "${fixture}" >/dev/null 2>&1
	status=$?
	if [[ ${status} -eq 0 ]]; then got=pass; else got=fail; fi

	if [[ ${got} == "${want}" ]]; then
		echo "ok: ${label} -> ${got}"
	else
		echo "FAIL: ${label} -> ${got}, expected ${want}" >&2
		failed=1
	fi
}

# A fixture identical to the original proves nothing, so every edit is checked
# to have actually landed before its case is trusted.
#
# The path comes back through a global rather than through `$(...)`: a command
# substitution runs in a subshell, so a `failed=1` set inside one is discarded
# and the harness would report success while announcing a broken fixture.
fixture_path=""
make_fixture() {
	local name="$1"
	shift
	fixture_path="${work_dir}/${name}.md"
	sed "$@" "${work_dir}/real.md" >"${fixture_path}"
	if diff -q "${work_dir}/real.md" "${fixture_path}" >/dev/null; then
		echo "FAIL: fixture ${name} is identical to the original; its edit did not apply" >&2
		failed=1
	fi
}

cp "${repo_root}/CHANGELOG.md" "${work_dir}/real.md"
run_case "the real changelog" "${work_dir}/real.md" pass

make_fixture no-definition "/^\[${version}\]: /d"
run_case "link definition deleted" "${fixture_path}" fail

make_fixture stale-endpoint "s|^\(\[${version}\]: .*\.\.\.\)${tag}\$|\1v0.0.0+00000000|"
run_case "link definition left at the previous tag" "${fixture_path}" fail

make_fixture unreleased-stale "s|compare/${tag}\.\.\.HEAD|compare/v0.0.0+00000000...HEAD|"
run_case "unreleased not advanced to the new tag" "${fixture_path}" fail

make_fixture no-heading "/^## \[${version}\] - /d"
run_case "version heading deleted" "${fixture_path}" fail

if [[ ${failed} -ne 0 ]]; then
	exit 1
fi

echo "release document tests passed"
