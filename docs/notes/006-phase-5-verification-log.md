# Phase 5 Verification Log

Status: automated gate passed; manual OS-surface verification pending
Source commit: 2ec3ba4c266d61d07df726622e3a0ec1c94b442f
Date: 2026-07-09
Tester: Codex via XcodeBuildMCP

## Environment

- Device or simulator: iPhone 17e simulator, 7ED9020C-A21E-425F-AF74-C71C40DA0A13
- OS version: iOS 26.5
- Xcode version: Xcode 26.6, build 17F113
- Notification authorization: not manually exercised in this session
- Widget installed: not manually installed in this session
- App Group identifier observed: `group.kr.donminzzi.QuestKeeper`

## Automated Gate

- `xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests`: pass, 63 tests passed and 0 failed
- `xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'`: pass, simulator build succeeded with 0 errors
- `git diff --check`: pass, no whitespace errors
- Raw-facts source guard: pass, no forbidden derived storage fields found under `QuestKeeper/Models`
- Simulator launch smoke: pass, `build_run_sim` installed and launched `kr.donminzzi.QuestKeeper`; screenshot captured at `/var/folders/rb/n38l4h_x6_927hsc8bmyl2980000gn/T/screenshot_optimized_ccbf6897-7bb7-4e25-b57d-c72b71ce7807.jpg`

## Manual Scenarios

### 1. Fresh Install And First Launch

Steps:
1. Install a clean build.
2. Launch the app.
3. Grant or deny notification permission explicitly.
4. Confirm the empty dungeon copy is safe and no crash occurs.

Observed: Simulator launch smoke passed and showed the empty quest state without a crash, but notification authorization was not manually granted or denied.

Result: blocked

### 2. Create Due-Soon And Later Quests

Steps:
1. Create one quest due within the due-soon window.
2. Create one quest due later.
3. Inspect pending notification requests in the debugger or app logs.
4. Add or refresh the QuestKeeper widget.

Observed: Not run in this session; requires hands-on quest creation plus pending notification and Home Screen widget inspection.

Result: blocked

### 3. Edit Deadline

Steps:
1. Edit an existing quest deadline.
2. Confirm old notification identifiers are removed before replacement requests are scheduled.
3. Confirm the widget reflects the updated deadline after reload or normal refresh.

Observed: Not run in this session; requires hands-on deadline editing plus notification request and widget refresh inspection.

Result: blocked

### 4. Complete Quest

Steps:
1. Complete a pending quest.
2. Confirm pending and delivered QuestKeeper notifications for that quest are removed.
3. Confirm total victories increase.
4. Confirm the widget no longer shows the quest as active.

Observed: Not run in this session; requires hands-on completion plus delivered Notification Center and widget inspection.

Result: blocked

### 5. Retry Tomorrow

Steps:
1. Use `내일 도전하기` on a visible daily grave.
2. Confirm the deadline moves to tomorrow and `completedAt` clears.
3. Confirm notifications are recreated for the new future deadline.
4. Confirm the widget shows the quest as active again.

Observed: Not run in this session; requires a visible daily grave, retry action, notification request inspection, and widget refresh inspection.

Result: blocked

### 6. Delete Quest

Steps:
1. Delete a pending quest.
2. Confirm notifications are removed.
3. Confirm the widget payload no longer includes the quest.

Observed: Not run in this session; requires hands-on deletion plus notification request and widget payload inspection.

Result: blocked

### 7. Reopen After Missed Deadline

Steps:
1. Create a quest with a near deadline.
2. Leave the app inactive until after the deadline.
3. Reopen the app.
4. Confirm the transient death/replay appears once.
5. Reopen again and confirm the same replay does not repeat.

Observed: Not run in this session; requires time-based app inactivity and repeated launch observation. The activation replay invariant is covered by `IntegrationVerificationTests.activationReplayReportsMissedQuestsOnceAfterLongInactivity`.

Result: blocked

## Notes

- WidgetKit refresh timing limitations: WidgetKit controls production refresh timing; unit tests verify cache payload derivation but do not prove Home Screen refresh latency.
- Notification delivery timing limitations: Unit tests verify scheduling, cancellation, reconcile, and delivered pruning paths; they do not prove real Notification Center presentation timing.
- Follow-up issues: manual OS-surface verification remains before Phase 5 can be accepted as fully closed.
