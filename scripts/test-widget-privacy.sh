#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
widget_view="$repo_root/QuestKeeperWidget/WidgetDungeonView.swift"

python3 - "$widget_view" <<'PY'
from pathlib import Path
import re
import sys

source = Path(sys.argv[1]).read_text()
sensitive_content = {
    "active quest status": r"StatusText\(deadlineText\(for: mob\), tone: \.color\(urgencyTint\(for: mob\)\)\)",
    "grave title": r"Text\(grave\.title\)",
    "active quest title": r"Text\(mob\.title\)",
    "active quest deadline": r"Text\(mob\.deadline, style: \.timer\)",
}

missing = []
for label, expression in sensitive_content.items():
    match = re.search(expression + r"\s*\n\s*\.privacySensitive\(\)", source)
    if match is None:
        missing.append(label)

if missing:
    print("Widget content missing privacy protection: " + ", ".join(missing), file=sys.stderr)
    raise SystemExit(1)

print("All user-sensitive widget content is privacy-sensitive.")
PY
