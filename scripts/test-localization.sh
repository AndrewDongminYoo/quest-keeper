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
default_value = re.compile(r'defaultValue:\s*"[^"]*"')


def strip_comments(text: str) -> str:
    """Blank out Swift comments, leaving string literals untouched.

    A regex cannot do this: `"// 한국어"` is a string, not a comment, and
    stripping it by pattern would hide exactly the stray literal this gate
    exists to reject. Comments become spaces so line numbers stay aligned.
    """
    out = []
    i, n, depth = 0, len(text), 0
    while i < n:
        if depth:  # inside /* */, which Swift allows to nest
            if text.startswith("/*", i):
                depth += 1; out.append("  "); i += 2
            elif text.startswith("*/", i):
                depth -= 1; out.append("  "); i += 2
            else:
                out.append("\n" if text[i] == "\n" else " "); i += 1
            continue
        if text.startswith("//", i):
            end = text.find("\n", i)
            end = n if end < 0 else end
            out.append(" " * (end - i)); i = end
            continue
        if text.startswith("/*", i):
            depth = 1; out.append("  "); i += 2
            continue
        for quote in ('\"\"\"', '"'):
            if text.startswith(quote, i):
                out.append(quote); i += len(quote)
                while i < n and not text.startswith(quote, i):
                    if text[i] == "\\" and i + 1 < n:
                        out.append(text[i : i + 2]); i += 2
                    else:
                        out.append(text[i]); i += 1
                if i < n:
                    out.append(quote); i += len(quote)
                break
        else:
            out.append(text[i]); i += 1
    return "".join(out)


def strip_allowed(text: str) -> str:
    # Comments first, string-aware, then the one place Korean is legitimate.
    return default_value.sub("", strip_comments(text))


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
