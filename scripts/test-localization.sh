#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ $# -gt 0 ]]; then
	catalogs=("$@")
else
	catalogs=(
		"${repo_root}/QuestKeeper/Localizable.xcstrings"
		"${repo_root}/QuestKeeperWidget/Localizable.xcstrings"
	)
fi

status=0

for catalog in "${catalogs[@]}"; do
	if [[ ! -s ${catalog} ]]; then
		echo "FAIL: missing or empty catalog: ${catalog}" >&2
		status=1
		continue
	fi

	if ! problems="$(
		/usr/bin/python3 - "${catalog}" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    catalog = json.load(handle)

strings = catalog.get("strings") or {}
if not strings:
    print("catalog has an empty or missing strings object")

for key, entry in sorted(strings.items()):
    localizations = entry.get("localizations", {})
    for locale in ("ko", "en"):
        localization = localizations.get(locale)
        if localization is None:
            print(f"{key} missing {locale}")
            continue
        unit = localization.get("stringUnit")
        variations = localization.get("variations")
        if unit is not None:
            if not unit.get("value", "").strip():
                print(f"{key} has an empty {locale} value")
        elif variations is not None:
            plural = variations.get("plural", {})
            if not plural:
                print(f"{key} has no {locale} plural variations")
            for category, variation in sorted(plural.items()):
                value = variation.get("stringUnit", {}).get("value", "")
                if not value.strip():
                    print(f"{key} has an empty {locale} plural.{category} value")
        else:
            print(f"{key} has no {locale} string unit")
PY
	)"; then
		echo "FAIL: ${catalog}: failed to parse catalog" >&2
		status=1
		continue
	fi

	if [[ -n ${problems} ]]; then
		while IFS= read -r problem; do
			echo "FAIL: ${catalog}: ${problem}" >&2
			status=1
		done <<<"${problems}"
	fi
done

stray="$(
	rg -n '"[^"]*[가-힣][^"]*"' \
		"${repo_root}/QuestKeeper" "${repo_root}/QuestKeeperShared" "${repo_root}/QuestKeeperWidget" \
		--glob '*.swift' |
		grep -vE ':[0-9]+: *(///|//)' |
		sed -E 's/defaultValue: *"[^"]*"//g' |
		grep '[가-힣]' || true
)"
if [[ -n ${stray} ]]; then
	echo "FAIL: hardcoded Korean literal outside a defaultValue:" >&2
	printf '%s\n' "${stray}" >&2
	status=1
fi

if [[ ${status} -eq 0 ]]; then
	echo "localization catalog tests passed"
fi

exit "${status}"
