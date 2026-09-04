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

stray_output="$(mktemp)"
trap 'rm -f -- "${stray_output}"' EXIT

if /usr/bin/python3 - "${repo_root}/QuestKeeper" "${repo_root}/QuestKeeperShared" "${repo_root}/QuestKeeperWidget" >"${stray_output}" <<'PY'; then
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
        # A raw literal opens with one or more `#` before the quote and closes
        # only on quote-plus-the-same-run. Without tracking the delimiter, the
        # bare quote inside #"a " // 한국어"# would end the string early and the
        # rest would be stripped as a comment.
        pounds = 0
        while i + pounds < n and text[i + pounds] == "#":
            pounds += 1
        hashes = "#" * pounds
        opener = next(
            (q for q in ('"""', '"') if text.startswith(hashes + q, i)),
            None,
        )
        if opener:
            closer = opener + hashes
            out.append(hashes + opener); i += pounds + len(opener)
            while i < n and not text.startswith(closer, i):
                # A backslash only escapes when it carries the same delimiter run.
                if text[i] == "\\" and text.startswith("\\" + hashes, i) and i + 1 + pounds < n:
                    out.append(text[i : i + 2 + pounds]); i += 2 + pounds
                else:
                    out.append(text[i]); i += 1
            if i < n:
                out.append(closer); i += len(closer)
            continue
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
	stray="$(<"${stray_output}")"
	if [[ -n ${stray} ]]; then
		echo "FAIL: hardcoded Korean literal outside a defaultValue: argument or a comment" >&2
		printf '%s\n' "${stray}" >&2
		status=1
	fi
else
	echo "FAIL: stray-Korean-literal scan crashed" >&2
	status=1
fi

if ! missing="$(
	/usr/bin/python3 - "${repo_root}" <<'KEYS'
import json
import pathlib
import re
import sys

# Which catalog must carry the keys each namespace declares. QuestKeeperShared
# compiles into both bundles, so its keys have to exist in both catalogs.
OWNERS = {
    "QuestKeeper/Views/AppStrings.swift": ["QuestKeeper"],
    "QuestKeeperWidget/WidgetStrings.swift": ["QuestKeeperWidget"],
    "QuestKeeperShared/SharedStrings.swift": ["QuestKeeper", "QuestKeeperWidget"],
}
key_pattern = re.compile(r'LocalizedStringResource\(\s*"([^"]+)"')
root = pathlib.Path(sys.argv[1])

catalogs = {}
for target in ("QuestKeeper", "QuestKeeperWidget"):
    path = root / target / "Localizable.xcstrings"
    catalogs[target] = set(json.loads(path.read_text(encoding="utf-8"))["strings"])

for source, targets in OWNERS.items():
    path = root / source
    if not path.exists():
        print(f"{source} is missing; the key cross-check cannot run")
        continue
    for key in sorted(set(key_pattern.findall(path.read_text(encoding="utf-8")))):
        for target in targets:
            if key not in catalogs[target]:
                print(f"{source} declares {key}, absent from {target}/Localizable.xcstrings")
KEYS
)"; then
	echo "FAIL: declared-key cross-check crashed" >&2
	status=1
elif [[ -n ${missing} ]]; then
	echo "FAIL: a string resource declares a key with no catalog entry" >&2
	printf '%s\n' "${missing}" >&2
	status=1
fi

if [[ ${status} -eq 0 ]]; then
	echo "localization catalog tests passed"
fi

exit "${status}"
