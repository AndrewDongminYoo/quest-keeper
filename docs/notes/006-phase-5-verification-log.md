# Phase 5 Verification Log

Status: ready for PR review; quest-list visibility follow-up noted
Source commit: e7323ec72be37b77a401847c655cfefc9acc898e
Date: 2026-07-09
Tester: Codex via XcodeBuildMCP

## Environment

- Device or simulator: iPhone 17e simulator, 7ED9020C-A21E-425F-AF74-C71C40DA0A13
- OS version: iOS 26.5
- Xcode version: Xcode 26.6, build 17F113
- Notification authorization: not verified
- Notification behavior: user manual check reports notification behavior works
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

Observed: Simulator launch smoke passed and showed the empty quest state without a crash, but notification authorization state was not recorded as authorized or denied.

Result: blocked

### 2. Create Due-Soon And Later Quests

Steps:
1. Create one quest due within the due-soon window.
2. Create one quest due later.
3. Inspect pending notification requests in the debugger or app logs.
4. Add or refresh the QuestKeeper widget.

Observed: User manual check reports notification behavior works. Home Screen widget inspection was not reported. Quest list visibility is lower than desired and should be tracked as a UI follow-up.

Result: blocked

### 3. Edit Deadline

Steps:
1. Edit an existing quest deadline.
2. Confirm old notification identifiers are removed before replacement requests are scheduled.
3. Confirm the widget reflects the updated deadline after reload or normal refresh.

Observed: User manual check reports notification behavior works. Deadline-edit replacement scheduling and widget refresh inspection were not separately reported.

Result: blocked

### 4. Complete Quest

Steps:
1. Complete a pending quest.
2. Confirm pending and delivered QuestKeeper notifications for that quest are removed.
3. Confirm total victories increase.
4. Confirm the widget no longer shows the quest as active.

Observed: User manual check reports notification behavior works. Completion-specific delivered notification pruning and widget inspection were not separately reported.

Result: blocked

### 5. Retry Tomorrow

Steps:
1. Use `내일 도전하기` on a visible daily grave.
2. Confirm the deadline moves to tomorrow and `completedAt` clears.
3. Confirm notifications are recreated for the new future deadline.
4. Confirm the widget shows the quest as active again.

Observed: User manual check reports `내일 도전하기` works and notification behavior works. Widget refresh inspection was not separately reported.

Result: pass

### 6. Delete Quest

Steps:
1. Delete a pending quest.
2. Confirm notifications are removed.
3. Confirm the widget payload no longer includes the quest.

Observed: User manual check reports notification behavior works. Delete-specific notification removal and widget payload inspection were not separately reported.

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
- Notification delivery timing limitations: Unit tests verify scheduling, cancellation, reconcile, and delivered pruning paths; user manual check reports notification behavior works, while the exact authorization state remains not verified.
- Follow-up issues: improve quest list visibility; finish separate Home Screen widget refresh inspection if strict Phase 5 closeout evidence is required.
