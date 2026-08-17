#!/usr/bin/env bash

# Release precondition: every store locale must name the app the same thing the
# build renders.
#
# Screenshots are captured once from one build and uploaded to every locale
# (`fastlane/Snapfile` lists them), and `Brand.displayName` is what their dungeon
# header shows. Deliver then replaces each locale's set wholesale
# (`overwrite_screenshots(true)`) and uploads the whole metadata tree unfiltered.
# So a locale whose `name.txt` disagrees with the build gets a listing whose
# title, description and screenshots do not name the same app.
#
# This is deliberately separate from `test-release-display-names.sh`. That one
# asserts a code invariant and holds at every commit; this one is a release
# precondition that stays red on purpose while a rename is half-applied, because
# claiming a name in App Store Connect is a manual, irreversible step that a
# commit cannot perform. Only the `release` lane runs it.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
brand_file="${repo_root}/QuestKeeperShared/Brand.swift"
metadata_dir="${repo_root}/fastlane/metadata"

if ! brand="$(
	sed -n 's/.*static let displayName = "\(.*\)".*/\1/p' "${brand_file}"
)" || [[ -z ${brand} ]]; then
	echo "FAIL: could not read Brand.displayName from ${brand_file}" >&2
	exit 1
fi

# `Brand.displayName` is upper case for the pixel header while a store name is
# title case, and title case is not recoverable from upper case, so the two are
# compared case-insensitively rather than derived from one another.
upper() { tr '[:lower:]' '[:upper:]'; }
brand_upper="$(printf '%s' "${brand}" | upper)"

failed=0
checked=0

for name_file in "${metadata_dir}"/*/name.txt; do
	locale="$(basename "$(dirname "${name_file}")")"
	store_name="$(head -1 "${name_file}")"
	checked=$((checked + 1))

	if [[ "$(printf '%s' "${store_name}" | upper)" != "${brand_upper}" ]]; then
		echo "FAIL: ${locale} store name is '${store_name}' but the build renders '${brand}'" >&2
		echo "      Screenshots from this build would advertise '${brand}' on a listing titled '${store_name}'." >&2
		failed=1
	fi

	description_file="$(dirname "${name_file}")/description.txt"
	if [[ -f ${description_file} ]] && ! grep -qF "${store_name}" "${description_file}"; then
		echo "FAIL: ${locale} description never names '${store_name}'" >&2
		failed=1
	fi
done

if [[ ${checked} -eq 0 ]]; then
	echo "FAIL: no ${metadata_dir}/*/name.txt found to check" >&2
	exit 1
fi

if [[ ${failed} -ne 0 ]]; then
	echo "" >&2
	echo "Release blocked: the store listing and the build disagree on the app name." >&2
	echo "Claim the name for the failing locale in App Store Connect first, then update its name.txt and description.txt together." >&2
	exit 1
fi

echo "store locale brand tests passed (${checked} locales against '${brand}')"
