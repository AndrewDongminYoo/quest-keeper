#!/usr/bin/env bash

# Asserts that the release paperwork names the release actually being cut.
#
# This lives here rather than inline in `release-tag.yml` for the same reason
# `release-version.sh` does: logic inside a workflow's `run:` block cannot be
# exercised without copying it, and a copy drifts. `test-release-documents.sh`
# runs this file against deliberately broken CHANGELOG fixtures.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
changelog="${1:-${repo_root}/CHANGELOG.md}"
project_file="${2:-${repo_root}/QuestKeeper.xcodeproj/project.pbxproj}"
release_root="${3:-${repo_root}/docs/releases}"
metadata_root="${4:-${repo_root}/fastlane/metadata}"

version_output="$(bash "${repo_root}/scripts/release-version.sh" "${project_file}")"
version="$(printf '%s\n' "${version_output}" | sed -n 's/^marketing_version=//p')"
tag="$(printf '%s\n' "${version_output}" | sed -n 's/^tag=//p')"

fail() {
	echo "FAIL: $1" >&2
	exit 1
}

grep -Fq "## [${version}] - " "${changelog}" ||
	fail "CHANGELOG.md has no '## [${version}] - <date>' heading"

# Keep a Changelog's headings are shortcut references, so a version with no
# link definition renders as literal brackets rather than as a broken link --
# and markdownlint's MD052 ignores shortcut syntax by default, so nothing else
# reports it. Existing is not the same as correct either: a definition left
# pointing at the previous tag compares the wrong range and still reads fine.
#
# Matching avoids regex entirely and compares with bash's `==` instead: the tag
# carries a `+` and the version carries dots, all regex metacharacters that
# would quietly match more than intended.
#
# The needle is anchored to the start of the line, not searched for anywhere in
# it, because a reference definition is only a definition at column zero.
# `grep -F "[1.3.0]: "` also matches `- [1.3.0]: https://...` inside a bullet,
# which leaves the heading unlinked while the check reports success.
#
# Uniqueness is established before the endpoint is read, because a stale
# definition sitting above a correct one otherwise yields a multi-line value
# whose tail still ends at the tag.
definition_line=""
expect_one_definition() {
	local label="$1" needle="$2" count=0 line
	definition_line=""
	while IFS= read -r line; do
		if [[ ${line} == "${needle}"* ]]; then
			count=$((count + 1))
			definition_line="${line}"
		fi
	done <"${changelog}"
	[[ ${count} -eq 1 ]] ||
		fail "expected exactly one line starting '${needle}' in CHANGELOG.md, found ${count} (${label})"
}

expect_one_definition "version link" "[${version}]: "
version_link="${definition_line}"
[[ ${version_link} == *"...${tag}" ]] ||
	fail "the [${version}] link must end at ${tag}, got: ${version_link}"

# The starting tag is checked for existence, not for being any particular
# release. This repository does not follow "the immediately preceding tag":
# 1.0.1 was a patch off 1.0.0, so 1.1.0 deliberately compares from
# v1.0.0+26072410 rather than from v1.0.1+26080501. Requiring the preceding tag
# would reject that entry, which is correct as written. Existence still rejects
# a fabricated or mistyped endpoint.
[[ ${version_link} == *"/compare/"* ]] ||
	fail "the [${version}] link must be a compare range, got: ${version_link}"
version_range="${version_link##*/compare/}"
start_tag="${version_range%%...*}"
git -C "${repo_root}" rev-parse --verify --quiet "refs/tags/${start_tag}" >/dev/null ||
	fail "the [${version}] link starts at '${start_tag}', which is not an existing tag (a shallow clone without tags would also report this)"

expect_one_definition "unreleased link" "[Unreleased]: "
unreleased_link="${definition_line}"
[[ ${unreleased_link} == *"compare/${tag}...HEAD" ]] ||
	fail "[Unreleased] must compare from ${tag}, got: ${unreleased_link}"

# Every listing locale, not just Korean. `prepare-release-notes.sh` requires a
# source file for each locale it discovers, so checking one of them here let a
# tag go green while another locale's notes were missing -- and a tag is
# effectively permanent, while the release lane never runs that preparation
# itself and would upload the previous version's notes for the gap.
# The locale list is captured before the loop rather than piped into it: a
# process substitution hides the producer's exit status, so a failing discovery
# would feed an empty list to a loop that then checks nothing and returns
# success.
locales="$(bash "${repo_root}/scripts/store-locales.sh" "${metadata_root}")" ||
	fail "could not determine the listing locales under ${metadata_root}"

locale_count=0
while IFS= read -r locale; do
	[[ -n ${locale} ]] || continue
	notes="${release_root}/${version}/${locale}.txt"
	test -s "${notes}" || fail "release notes are missing or empty: ${notes}"
	locale_count=$((locale_count + 1))
done <<<"${locales}"

[[ ${locale_count} -gt 0 ]] ||
	fail "no listing locale was discovered, so no release notes were checked"

echo "release documents validated for ${version} (${tag})"
