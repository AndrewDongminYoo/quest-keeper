#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
widget_plist="$repo_root/QuestKeeperWidget/Info.plist"
project_file="$repo_root/QuestKeeper.xcodeproj/project.pbxproj"

if ! display_name="$(
  /usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$widget_plist" 2>&1
)"; then
  echo "FAIL: QuestKeeperWidget must define CFBundleDisplayName" >&2
  exit 1
fi

if [[ "$display_name" != "Quest Keeper" ]]; then
  echo "FAIL: expected widget CFBundleDisplayName to be Quest Keeper, got $display_name" >&2
  exit 1
fi

app_display_name_count="$(
  grep -c 'INFOPLIST_KEY_CFBundleDisplayName = "Quest Keeper";' "$project_file" || true
)"
if [[ "$app_display_name_count" -ne 2 ]]; then
  echo "FAIL: expected both app configurations to use CFBundleDisplayName Quest Keeper" >&2
  exit 1
fi

echo "release display name tests passed"
