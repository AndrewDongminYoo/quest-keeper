#!/usr/bin/env bash

# Prints one App Store listing locale per line.
#
# `deliver` only treats a metadata directory as a listing locale if it holds a
# `name.txt`, which is what excludes `review_information`. Reading the set from
# the metadata tree rather than listing it in each caller is what stops a newly
# added locale from being silently skipped by one script while another picks it
# up -- exactly the split that let a release tag go green while `en-US.txt` was
# never checked at all.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
metadata_root="${1:-${repo_root}/fastlane/metadata}"

found=0
for candidate in "${metadata_root}"/*/; do
	[[ -f "${candidate}name.txt" ]] || continue
	basename "${candidate}"
	found=1
done

if [[ ${found} -eq 0 ]]; then
	echo "no listing locale found under ${metadata_root}" >&2
	exit 1
fi
