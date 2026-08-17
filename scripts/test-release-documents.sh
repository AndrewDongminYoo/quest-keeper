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

# If this fails, `work_dir` is empty, every fixture path becomes `/<name>.md`,
# and the writes are refused -- at which point the validator rejects each
# missing file and all four negative cases go green for the wrong reason.
# Observed for real in a read-only Codex sandbox, where the harness happily
# printed four "ok" lines while creating nothing.
work_dir="$(mktemp -d)" || {
	echo "FAIL: could not create a temporary directory" >&2
	exit 1
}
if [[ -z ${work_dir} || ! -d ${work_dir} || ! -w ${work_dir} ]]; then
	echo "FAIL: temporary directory is unusable: '${work_dir}'" >&2
	exit 1
fi
trap 'rm -rf "${work_dir}"' EXIT

version_output="$(bash "${repo_root}/scripts/release-version.sh")"
version="$(printf '%s\n' "${version_output}" | sed -n 's/^marketing_version=//p')"
tag="$(printf '%s\n' "${version_output}" | sed -n 's/^tag=//p')"

failed=0

run_case() {
	local label="$1" fixture="$2" want="$3" status got

	# A negative case that never got a fixture would "fail" because the file is
	# absent rather than because the defect was caught, which is the same green
	# as a working check.
	if [[ ! -s ${fixture} ]]; then
		echo "FAIL: ${label} -> its fixture is missing or empty: '${fixture}'" >&2
		failed=1
		return
	fi

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
#
# The filter is passed as a whole command rather than as sed arguments, because
# inserting a line needs a tool whose replacement understands a newline and BSD
# sed's does not.
fixture_path=""
make_fixture() {
	local name="$1"
	shift
	fixture_path="${work_dir}/${name}.md"
	if ! "$@" <"${work_dir}/real.md" >"${fixture_path}"; then
		echo "FAIL: fixture ${name} could not be written" >&2
		failed=1
		return
	fi
	if [[ ! -s ${fixture_path} ]]; then
		echo "FAIL: fixture ${name} is empty" >&2
		failed=1
		return
	fi
	# `diff` distinguishes identical from different, but exits non-zero for a
	# missing file too, so the emptiness check above has to come first.
	if diff -q "${work_dir}/real.md" "${fixture_path}" >/dev/null; then
		echo "FAIL: fixture ${name} is identical to the original; its edit did not apply" >&2
		failed=1
	fi
}

if ! cp "${repo_root}/CHANGELOG.md" "${work_dir}/real.md" || [[ ! -s "${work_dir}/real.md" ]]; then
	echo "FAIL: could not stage CHANGELOG.md into ${work_dir}" >&2
	exit 1
fi
run_case "the real changelog" "${work_dir}/real.md" pass

make_fixture no-definition sed "/^\[${version}\]: /d"
run_case "link definition deleted" "${fixture_path}" fail

make_fixture stale-endpoint sed "s|^\(\[${version}\]: .*\.\.\.\)${tag}\$|\1v0.0.0+00000000|"
run_case "link definition left at the previous tag" "${fixture_path}" fail

make_fixture unreleased-stale sed "s|compare/${tag}\.\.\.HEAD|compare/v0.0.0+00000000...HEAD|"
run_case "unreleased not advanced to the new tag" "${fixture_path}" fail

make_fixture no-heading sed "/^## \[${version}\] - /d"
run_case "version heading deleted" "${fixture_path}" fail

# A stale definition placed *before* the correct one. The order matters: with
# the stale line last the endpoint test already rejects it, so only this
# arrangement exercises the uniqueness check.
stale_line="[${version}]: https://example.com/compare/v0.0.0+00000000...v0.0.0+00000000"
make_fixture duplicate-version-definition \
	perl -pe "s|^(\\Q[${version}]: \\E.*)\$|${stale_line}\\n\$1|"
run_case "two conflicting version link definitions" "${fixture_path}" fail

# The single quotes are the point here: `$1`, `\Q`, `\E` and `\n` belong to
# perl and must reach it unexpanded. Unlike the fixture above, this pattern
# needs no shell variable, so nothing has to be interpolated.
# shellcheck disable=SC2016
make_fixture duplicate-unreleased-definition \
	perl -pe 's|^(\Q[Unreleased]: \E.*)$|[Unreleased]: https://example.com/compare/v0.0.0+00000000...HEAD\n$1|'
run_case "two conflicting unreleased definitions" "${fixture_path}" fail

# A definition indented into a list item is not a reference definition at all,
# so the heading stays unlinked while every substring search still finds it.
make_fixture definition-inside-a-bullet sed "s|^\(\[${version}\]: \)|- \1|"
run_case "definition demoted to a bullet" "${fixture_path}" fail

# The endpoint can be right while the range starts somewhere invented.
make_fixture fabricated-start-tag \
	sed "s|/compare/[^/]*\.\.\.|/compare/v0.0.0+00000000...|"
run_case "comparison starts at a tag that does not exist" "${fixture_path}" fail

# The release notes are checked per listing locale, so each locale needs its own
# case: hardcoding Korean is exactly what let a tag go green while `en-US.txt`
# was never looked at. The fixtures here vary the release root instead of the
# changelog, so they run the validator directly.
notes_case() {
	local label="$1" drop_locale="$2" release_root status

	release_root="${work_dir}/releases-without-${drop_locale}"
	mkdir -p "${release_root}/${version}"
	local copied=0 locale
	while IFS= read -r locale; do
		[[ -n ${locale} ]] || continue
		[[ ${locale} == "${drop_locale}" ]] && continue
		cp "${repo_root}/docs/releases/${version}/${locale}.txt" \
			"${release_root}/${version}/${locale}.txt"
		copied=$((copied + 1))
	done <<<"${listing_locales}"

	# If nothing was copied the fixture proves nothing: the validator would
	# reject it for the first missing locale whichever one that is.
	if [[ ${copied} -eq 0 ]]; then
		echo "FAIL: ${label} -> fixture kept no other locale, so it cannot isolate ${drop_locale}" >&2
		failed=1
		return
	fi

	bash "${script_path}" "${work_dir}/real.md" "" "${release_root}" >/dev/null 2>&1
	status=$?
	if [[ ${status} -ne 0 ]]; then
		echo "ok: ${label} -> fail"
	else
		echo "FAIL: ${label} -> pass, expected fail" >&2
		failed=1
	fi
}

listing_locales="$(bash "${repo_root}/scripts/store-locales.sh")" || {
	echo "FAIL: could not determine the listing locales" >&2
	exit 1
}

while IFS= read -r listing_locale; do
	[[ -n ${listing_locale} ]] || continue
	notes_case "release notes missing for ${listing_locale}" "${listing_locale}"
done <<<"${listing_locales}"

if [[ ${failed} -ne 0 ]]; then
	exit 1
fi

echo "release document tests passed"
