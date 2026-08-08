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

if ! stray="$(
	/usr/bin/python3 - "${repo_root}/QuestKeeper" "${repo_root}/QuestKeeperShared" "${repo_root}/QuestKeeperWidget" <<'PY'
import pathlib
import re
import sys

hangul = re.compile(r"[가-힣]")
block_comment = re.compile(r"/\*.*?\*/", re.DOTALL)
line_comment = re.compile(r"//[^\n]*")
default_value = re.compile(r'defaultValue:\s*"[^"]*"')


def strip_allowed(text: str) -> str:
    # Block comments first (may contain a quoted Korean example), keeping
    # line numbers aligned by replacing the match with the newlines it held.
    text = block_comment.sub(lambda match: "\n" * match.group(0).count("\n"), text)
    # Korean copy is legitimate only as a defaultValue: argument.
    text = default_value.sub("", text)
    # Line comments last (covers both a leading /// doc comment and a
    # trailing // comment on an otherwise-code line).
    text = line_comment.sub("", text)
    return text


for root in sys.argv[1:]:
    for path in sorted(pathlib.Path(root).rglob("*.swift")):
        original = path.read_text(encoding="utf-8")
        cleaned = strip_allowed(original)
        original_lines = original.splitlines()
        for lineno, cleaned_line in enumerate(cleaned.splitlines(), start=1):
            if hangul.search(cleaned_line):
                print(f"{path}:{lineno}:{original_lines[lineno - 1].strip()}")
PY
)"; then
	echo "FAIL: stray-Korean-literal scan crashed" >&2
	status=1
elif [[ -n ${stray} ]]; then
	echo "FAIL: hardcoded Korean literal outside a defaultValue: argument or a comment" >&2
	printf '%s\n' "${stray}" >&2
	status=1
fi

if [[ ${status} -eq 0 ]]; then
	echo "localization catalog tests passed"
fi

exit "${status}"
