#!/usr/bin/env bash
set -euo pipefail

# Guards that every user-sensitive quest text in the Home Screen widget carries
# `.privacySensitive()`, so private quest details are redacted on the Lock Screen /
# StandBy / Always-On surfaces. This is a source-level regression check — SwiftUI
# view modifiers are not introspectable from a unit test without a view-inspection
# dependency, which this dep-minimal project deliberately avoids.
#
# Robust by design: each sensitive view is anchored by a STABLE content substring,
# then the check walks that view's trailing modifier chain and passes as long as
# `.privacySensitive()` appears anywhere in it — tolerant of modifier reordering,
# intervening modifiers, and reformatting (the previous version required strict
# next-line adjacency and broke on any of those).

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
widget_view="$repo_root/QuestKeeperWidget/WidgetDungeonView.swift"

python3 - "$widget_view" <<'PY'
import sys
from pathlib import Path

lines = Path(sys.argv[1]).read_text().splitlines()

# label -> stable substring anchoring the view that renders private quest data.
sensitive = {
    "active quest status": "StatusText(deadlineText(for: mob)",
    "grave title": "Text(grave.title)",
    "active quest title": "Text(mob.title)",
    "active quest deadline": "Text(mob.deadline",
}


def chain_has_privacy(anchor: int) -> bool:
    """True if `.privacySensitive()` sits in the anchored view's modifier chain.

    The chain is the anchor line itself plus the run of following lines whose first
    non-space character is `.` (a SwiftUI modifier). A blank or non-modifier line
    ends the chain (i.e. the next sibling view), so a modifier on an unrelated view
    can't satisfy the check.
    """
    if ".privacySensitive()" in lines[anchor]:
        return True
    i = anchor + 1
    while i < len(lines):
        stripped = lines[i].strip()
        if not stripped.startswith("."):
            break
        if ".privacySensitive()" in stripped:
            return True
        i += 1
    return False


failures = []
for label, needle in sensitive.items():
    anchor = next((n for n, line in enumerate(lines) if needle in line), None)
    if anchor is None:
        failures.append(f"{label}: anchor '{needle}' not found (view renamed or removed?)")
    elif not chain_has_privacy(anchor):
        failures.append(f"{label}: '{needle}' is not marked .privacySensitive()")

if failures:
    print("FAIL: widget content missing privacy protection:", file=sys.stderr)
    for failure in failures:
        print(f"  - {failure}", file=sys.stderr)
    raise SystemExit(1)

print("PASS: all user-sensitive widget content is marked .privacySensitive().")
PY
