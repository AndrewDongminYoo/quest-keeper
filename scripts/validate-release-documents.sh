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
# Matching is fixed-string and suffix-anchored on purpose. The tag carries a
# `+` and the version carries dots, all regex metacharacters that would quietly
# match more than intended.
version_link="$(grep -F "[${version}]: " "${changelog}" || true)"
[[ -n ${version_link} ]] ||
	fail "CHANGELOG.md has no '[${version}]: <url>' link definition"
[[ ${version_link} == *"...${tag}" ]] ||
	fail "the [${version}] link must end at ${tag}, got: ${version_link}"

unreleased_link="$(grep -F "[Unreleased]: " "${changelog}" || true)"
[[ -n ${unreleased_link} ]] ||
	fail "CHANGELOG.md has no '[Unreleased]: <url>' link definition"
[[ ${unreleased_link} == *"compare/${tag}...HEAD" ]] ||
	fail "[Unreleased] must compare from ${tag}, got: ${unreleased_link}"

notes="${release_root}/${version}/ko.txt"
test -s "${notes}" || fail "release notes are missing or empty: ${notes}"

echo "release documents validated for ${version} (${tag})"
