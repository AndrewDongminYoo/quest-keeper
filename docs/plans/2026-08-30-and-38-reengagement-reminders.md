# AND-38 User-Controlled Reengagement Reminders Implementation Plan

> **For implementation:** Follow the tasks in order and keep each behavior test-first.

**Goal:** Add optional, user-configured local reengagement reminders with deterministic scheduling, safe tap attribution, and local measurement.

**Architecture:** Keep reminder configuration in one `UserDefaults` value object, compute requests in a pure planner, and reconcile them from the existing notification service.
Use the existing local retention event store and activation writer for measurement rather than adding a dependency or a new persistence model.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, UserNotifications, Swift Testing.

## Success Criteria

1. User-controlled settings → verify: planner and settings-store tests show disabled defaults, every control, quiet-hour suppression, and deterministic plans.
2. Full notification lifecycle → verify: notification-service tests show no duplicate requests, capacity reservation, no automatic permission prompt, and update-on-activation reconciliation.
3. Relevant route and measurement → verify: routing and report tests show only the same foreground execution can produce a notification completion event.
4. User-facing delivery → verify: `bash scripts/test-localization.sh` and the focused unit-test suite pass.

## File Ownership And Scope

Modify notification planner and service files under `QuestKeeper/Notifications/`.
Modify app lifecycle and presentation wiring in `QuestKeeperApp.swift`, `ContentView.swift`, `HomeDungeonBoardView.swift`, and `QuestEditor.swift`.
Add one reminder settings sheet and localized strings.
Modify retention event and report files in `QuestKeeperShared/`.
Add focused Swift Testing files under `QuestKeeperTests/`.
Do not modify quest facts, widget payloads, or AND-159 behavior.

## Task 1: Add Pure Settings And Planner Tests

**Files:**

- Create: `QuestKeeperTests/ReengagementReminderPlannerTests.swift`
- Create: `QuestKeeperTests/ReengagementReminderSettingsStoreTests.swift`

**Step 1: Write the failing tests.**

Cover disabled settings, quiet-hour suppression, daily and weekday request identifiers, deterministic pending-target ordering, and privacy-safe copy.
Use future dates based on `Date.now` whenever a test inspects a pending notification trigger.

**Step 2: Run the focused test target and confirm it fails because the implementation does not exist.**

Run: `xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.5' -only-testing:QuestKeeperTests/ReengagementReminderPlannerTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2`

**Step 3: Implement the minimum pure types.**

Create `ReengagementReminderSettings`, `ReengagementReminderSettingsStore`, `ReengagementReminderFrequency`, `ReengagementReminderPurpose`, `ReengagementQuietHours`, `ReengagementReminderPlan`, and `ReengagementReminderPlanner`.
Keep the planner independent of `UserDefaults`, SwiftData, and `UNUserNotificationCenter`.

**Step 4: Re-run the focused test target and confirm it passes.**

## Task 2: Reconcile Reengagement Requests With Deadline Requests

**Files:**

- Modify: `QuestKeeper/Notifications/QuestNotificationPlanner.swift`
- Modify: `QuestKeeper/Notifications/QuestNotificationService.swift`
- Modify: `QuestKeeperTests/QuestNotificationServiceTests.swift`

**Step 1: Add failing service tests.**

Cover one or five reserved request slots, deterministic remove-before-add reconciliation, existing deadline request preservation, repeated reconciliation, disabled or invalid settings cleanup, and a no-prompt single-quest sync.
Update the fake center so its platform cap counts both prefixes.

**Step 2: Implement full reconciliation.**

Inject the settings store into `QuestNotificationService`.
Plan reengagement requests first, reserve their slots for deadline planning, remove both request families, and create repeating calendar triggers for reengagement plans.
Do not let `sync` request authorization.

**Step 3: Run the focused service tests.**

## Task 3: Route Taps And Record Attributed Completion

**Files:**

- Modify: `QuestKeeper/Notifications/NotificationRouteStore.swift`
- Modify: `QuestKeeper/Notifications/NotificationDelegate.swift`
- Modify: `QuestKeeper/ContentView.swift`
- Modify: `QuestKeeperShared/RetentionEvent.swift`
- Modify: `QuestKeeperShared/RetentionEventRecorder.swift`
- Modify: `QuestKeeperShared/RetentionReport.swift`
- Modify: `QuestKeeperTests/NotificationRoutingTests.swift`
- Modify: `QuestKeeperTests/RetentionEventRecorderTests.swift`

**Step 1: Add failing route and recorder tests.**

Cover a reengagement route, a normal deadline route, an unavailable target, event deduplication, and source or quest-ID validation.

**Step 2: Implement the route value and event actions.**

Retain a route UUID only while the app stays in the same foreground execution.
Record opened only after the target resolves and record completion only for the same quest and route UUID.
Clear attribution on background.

**Step 3: Run routing and recorder tests.**

## Task 4: Persist The Three Metrics

**Files:**

- Create: `QuestKeeperShared/ReengagementReminderReport.swift`
- Modify: `QuestKeeper/Measurement/RetentionBaselineWriter.swift`
- Modify: `QuestKeeperTests/RetentionBaselineStoreTests.swift`
- Create: `QuestKeeperTests/ReengagementReminderReportTests.swift`

**Step 1: Add failing report tests.**

Cover grant, disable, and attributed-completion numerators and denominators, duplicate actions, invalid rows, and empty denominators.

**Step 2: Implement the pure report and atomic App Group store.**

Use `RetentionRate` and the existing JSON encoder.
Keep the core retention report unchanged except for accepting valid reengagement event combinations.

**Step 3: Write the report from the existing genuine-activation writer.**

**Step 4: Run report and store tests.**

## Task 5: Add The Settings Flow And Stop Automatic Prompts

**Files:**

- Create: `QuestKeeper/Views/ReengagementReminderSettingsSheet.swift`
- Modify: `QuestKeeper/Views/HomeDungeonBoardView.swift`
- Modify: `QuestKeeper/Views/AppStrings.swift`
- Modify: `QuestKeeper/Localizable.xcstrings`
- Modify: `QuestKeeper/ContentView.swift`
- Modify: `QuestKeeper/Views/QuestEditor.swift`
- Modify: `QuestKeeper/QuestKeeperApp.swift`

**Step 1: Add focused behavior tests before wiring.**

Cover first-quest gating and explicit-enable authorization through the test seam where practical.

**Step 2: Implement the board entry point and sheet.**

Expose enabled state, time, frequency, quiet hours, purpose, permission status, validation text, and the system settings action for denial.
Save valid edits through one ContentView callback that records events and invokes full reconciliation.

**Step 3: Change editor save to `syncWithoutRequestingAuthorization`.**

This removes the existing automatic request path while preserving future deadline scheduling after a permission decision.

**Step 4: Add localized Korean and English resources.**

Use the existing `AppStrings` namespace and keep all notification text title-free.

## Task 6: Verify The Integrated Change

**Step 1: Run fast syntax and localization checks.**

Run `swiftc -parse -swift-version 6` on each changed Swift source file and `bash scripts/test-localization.sh`.

**Step 2: Run focused unit tests.**

Run the new planner, settings store, notification service, routing, event recorder, report, and baseline store suites with one non-parallel simulator worker.

**Step 3: Run the complete unit suite.**

Run `xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.5' -only-testing:QuestKeeperTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2 -resultBundlePath /tmp/quest-keeper-and38-final.xcresult`.

**Step 4: Inspect the result bundle and working tree.**

Confirm actual test execution, zero failures, intentional paths only, and no generated artifacts.
