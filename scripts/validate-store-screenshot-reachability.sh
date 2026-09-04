#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_file="${1:-${repo_root}/QuestKeeperUITests/StoreScreenshotUITests.swift}"

if [[ ! -f ${test_file} ]]; then
	echo "store screenshot test file not found: ${test_file}" >&2
	exit 1
fi

for forbidden_argument in -dailyFocusLoopEnabled -recoveryLoopVariant; do
	if grep -Fq -- "${forbidden_argument}" "${test_file}"; then
		echo "store screenshots must not enable DEBUG-only feature argument: ${forbidden_argument}" >&2
		exit 1
	fi
done

echo "store screenshot routes use the Release feature-availability policy"
