# Task Completion Checklist

Run before considering a coding task done:

1. Unit-test gate (Swift Testing):
   `xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests`
2. If persistence (`QuestKeeper/Models/`) changed, run the derived-state guard — it MUST return nothing:
   `! rg -n '(var|let) +(hp|isDead|mobLevel|urgency|victories|graves|outcome|retry|monster|notificationID|isNotificationScheduled|reminderEnabled|lastNotificationFiredAt|widgetID)' QuestKeeper/Models/`
3. If target/signing/entitlements/App Group wiring changed, also run the build gate:
   `xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'`
4. Must compile clean under Swift 6 strict concurrency (`SWIFT_STRICT_CONCURRENCY = complete`) — no new warnings.
5. For user-facing feature work, do manual QA through the actual surface (create near-deadline quest → complete → victory count; far-future quest → elder guide; miss + reopen → daily grave; 내일 도전하기 → back to active; widget reflects changes). See `README.md` Manual QA.

No separate lint/format tooling is wired in-repo (no SwiftLint/SwiftFormat config present). See `mem:suggested_commands` for command details.
