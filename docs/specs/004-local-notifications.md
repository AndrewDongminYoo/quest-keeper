# Spec 004 — Local Notification Lifecycle (Phase 3)

Status: planned
Depends on: 003 (task CRUD & hero view)
Blocks: Phase 4 (home-screen widget)

Figma reference: `quest-dungeon-screen` (`node-id=9:4`) is a rough screen concept, not a behavioral source of truth.
Use it as visual pressure only: notifications should fit into the existing active quest / graveyard flow, with a quiet status affordance near quest creation or rows.
Do **not** import the concept's HP / XP bars into the data model; Phase 1 settled that there is no stored HP, and deaths remain replayed from facts.

## Goal

Implement the `UserNotifications` lifecycle promised in BLUEPRINT Phase 3:

- ask for notification permission with a clear denial path;
- schedule deadline-related notifications when a pending quest is created or edited;
- cancel pending notifications when the quest completes or its deadline changes;
- avoid duplicate requests by deriving stable notification identifiers from the quest id;
- deep-link a notification tap back to the matching quest.

Notifications are an OS side effect, not a source of game truth.
The app must still derive victories, graves, urgency, and mob level from `QuestSnapshot` + `now`.
If every pending notification is lost by iOS, a reinstall, or a bug, the next app open must still reconstruct the correct hero state.

## Core Rule

Do not store notification lifecycle state on `Quest`.

Allowed stored facts remain exactly the Phase 1 facts:

- `id`
- `title`
- `deadline`
- `completedAt`
- `importance`

Disallowed model fields:

- `notificationID`
- `isNotificationScheduled`
- `reminderEnabled`
- `lastNotificationFiredAt`
- any HP / death / urgency / mob-level state

Notification identity is deterministic:

```swift
quest.<quest-id>.dueSoon
quest.<quest-id>.deadline
```

Because identifiers are derived from `Quest.id`, completion/edit/delete can cancel without looking up a stored request id.

## Product Behavior

### 1. Permission flow

Default: request authorization lazily, at the first moment the user saves a future-deadline pending quest.
This gives the iOS prompt context and avoids asking on cold launch before the user has made a quest.

Handle statuses from `UNNotificationSettings.authorizationStatus`:

- `.notDetermined` — request `alert` + `sound`.
- `.authorized` / `.provisional` / `.ephemeral` — schedule normally. Provisional delivery may be quiet; that is acceptable.
- `.denied` — still save the quest, skip scheduling, and show a non-blocking "알림 꺼짐" affordance that can open the app's Settings page.
- `@unknown default` — treat as not scheduleable and log.

Do not request badge permission in Phase 3.
A badge count needs its own semantics and would become another lifecycle to maintain.

### 2. Notification kinds

Each pending quest can have up to two local notifications:

1. **Due soon** — default fire time: `deadline - GameBalance.notificationLeadTime`.
2. **Deadline** — fire time: `deadline`.

Add one tuning constant:

```swift
nonisolated enum GameBalance {
    static let notificationLeadTime: TimeInterval = 60 * 60
}
```

Scheduling rules:

- If `quest.completedAt != nil`, schedule nothing.
- If `quest.deadline <= now`, schedule nothing. A past-deadline quest is already a grave by derivation.
- If the due-soon fire time is `<= now`, skip only the due-soon request and still schedule the deadline request if the deadline is future.
- Use `UNCalendarNotificationTrigger(dateMatching:repeats:false)` per BLUEPRINT.
- Include `year`, `month`, `day`, `hour`, `minute`, and `second` components from the fire date.
- Use local wall-clock behavior. On app activation, reconcile notifications again against the stored absolute `Date` facts.

Recommended copy:

- Due soon title: `퀘스트 마감 임박`
- Due soon body: `<title> · 곧 마감됩니다`
- Deadline title: `퀘스트 마감`
- Deadline body: `<title> 마감 시간이 되었습니다`

Do not claim "무덤이 생겼습니다" inside the notification body.
The grave is still derived when the app opens; notification delivery itself must not become the death event.

### 3. Create / edit lifecycle

Creating a future pending quest:

```plaintext
save Quest fact -> check/request authorization -> remove existing identifiers defensively -> add dueSoon/deadline requests
```

Editing title / deadline / importance:

```plaintext
save new facts -> remove both old deterministic identifiers -> add requests from the new facts
```

Remove-before-add is mandatory.
It prevents duplicate notification requests when a user edits a deadline multiple times.

Importance changes do not affect fire dates, but the lifecycle should still resync from the whole quest after save.
That keeps the action boundary simple and avoids special cases.

### 4. Complete / delete lifecycle

Completing a quest:

```plaintext
write completedAt -> remove pending dueSoon/deadline requests -> remove delivered dueSoon/deadline notifications
```

Removing delivered notifications is not a game-rule requirement, but it prevents stale notification-center entries for a quest that is now complete.

Deleting a pending or victorious quest:

```plaintext
delete Quest -> remove pending and delivered dueSoon/deadline notifications
```

Graves are still undeletable, so they need no delete notification path.

### 5. App activation repair pass

On `.active`, after Phase 2's state replay has run, reconcile notifications for all quests.
This is the safety net for permission changes, app termination during a save, and old pending requests left by prior builds.

The repair pass should:

- ask `UNUserNotificationCenter` for pending requests;
- compute the expected request identifiers for current pending future quests;
- remove stale QuestKeeper notification requests not in the expected set;
- schedule missing expected requests if authorization allows it.

Keep this bounded and boring: the app is local-only and single-device, so a full pass over the small quest list is acceptable.
If the list later grows large enough to matter, optimize after measuring.

### 6. Notification tap routing

Every request carries user info:

```swift
[
    "questID": quest.id.uuidString,
    "kind": kind.rawValue
]
```

Do not add a custom URL scheme for Phase 3.
Local notifications already deliver `UNNotificationResponse`; adding URL routing now is unnecessary surface area.

Routing contract:

- App startup registers a `UNUserNotificationCenterDelegate`.
- The delegate extracts `questID` from the response and hands it to a main-actor route store.
- `ContentView` consumes the pending `UUID` after `@Query` has loaded.
- If the quest is still `.pending`, open the existing edit flow.
- If the quest is `.grave` or `.victory`, present a read-only resolution sheet or highlight the matching row. Do not allow editing a resolved quest just because it came from a notification.
- If the quest no longer exists, drop the route silently after logging.

The route is UI state only; it is not persisted.

## Design

### 1. Pure planner

Create a pure planning seam over raw facts:

```swift
nonisolated enum QuestNotificationPlanner {
    static func identifiers(for questID: UUID) -> [String]
    static func plans(for snapshot: QuestSnapshot, title: String, now: Date) -> [QuestNotificationPlan]
}

nonisolated struct QuestNotificationPlan: Sendable, Equatable {
    let identifier: String
    let questID: UUID
    let kind: QuestNotificationKind
    let fireDate: Date
    let title: String
    let body: String
}

nonisolated enum QuestNotificationKind: String, Sendable {
    case dueSoon
    case deadline
}
```

This planner is where edge cases live.
It is testable without `UNUserNotificationCenter`, SwiftData, or the simulator notification permission state.

### 2. Notification service

Create one service that owns the OS side effect:

```swift
@MainActor
final class QuestNotificationService {
    func authorizationStatus() async -> QuestNotificationAuthorization
    func requestAuthorizationIfNeeded() async -> QuestNotificationAuthorization
    func sync(quest: Quest, now: Date) async
    func cancel(questID: UUID) async
    func reconcile(quests: [Quest], now: Date) async
}
```

The public methods take `Quest` only at the UI/action boundary.
Internally, immediately convert to `(snapshot, title)` before planning so the scheduling rules still depend on facts, not model object behavior.

Use a small protocol wrapper around `UNUserNotificationCenter` only if needed for tests.
Do not introduce a third-party dependency for this.

### 3. SwiftUI integration

Keep `QuestActions` focused on fact mutations.
Do not put `UserNotifications` calls in the derivation layer or in `QuestSnapshot`.

Integration points:

- `QuestEditor.save()` — after inserting or editing the quest, trigger `service.sync(quest:now:)`.
- `ContentView.complete(_:)` — after `QuestActions.complete`, trigger `service.cancel(questID:)`.
- `ContentView.delete(_:)` — before or after `modelContext.delete`, trigger `service.cancel(questID:)`; capture `quest.id` before deletion.
- `ContentView.onBecameActive(now:)` — keep the existing reconstruction ordering, then trigger `service.reconcile(quests:now:)`.
- `QuestRow` or `QuestEditor` — show a restrained "알림 꺼짐" state only when permission is denied. Match the Figma concept's dense quest-row style; do not add a separate notification dashboard.

All scheduling calls should be non-blocking for the save path.
If scheduling fails, the quest still saves because the stored facts are the product truth.
Log the failure and expose a quiet UI state if permission is the cause.

## Files

- `QuestKeeper/Derivation/GameBalance.swift` — add `notificationLeadTime`.
- `QuestKeeper/Notifications/QuestNotificationKind.swift` — notification kinds and deterministic identifiers.
- `QuestKeeper/Notifications/QuestNotificationPlan.swift` — sendable value plan.
- `QuestKeeper/Notifications/QuestNotificationPlanner.swift` — pure edge-case planner.
- `QuestKeeper/Notifications/QuestNotificationService.swift` — authorization, schedule, cancel, reconcile.
- `QuestKeeper/Notifications/NotificationRouteStore.swift` — main-actor pending quest id from notification responses.
- `QuestKeeper/Notifications/NotificationDelegate.swift` or app delegate adapter — `UNUserNotificationCenterDelegate` bridge.
- `QuestKeeper/QuestKeeperApp.swift` — register the delegate/store early.
- `QuestKeeper/ContentView.swift` — complete/delete/reconcile integration and route consumption.
- `QuestKeeper/Views/QuestEditor.swift` — sync notification requests after save.
- `QuestKeeper/Views/QuestRow.swift` — optional quiet denied-permission affordance, only if the UI state needs it.
- `QuestKeeperTests/QuestNotificationPlannerTests.swift` — pure planner tests.
- `QuestKeeperTests/QuestNotificationServiceTests.swift` — fake-center lifecycle tests if the center wrapper is introduced.
- `QuestKeeperTests/NotificationRoutingTests.swift` — userInfo parser / route-store tests.

## Out of Scope

- Push notifications, remote notifications, backend delivery, CloudKit, accounts.
- Live Activities / Dynamic Island countdowns.
- Per-quest custom reminder offsets.
- Snooze, repeat schedules, recurring quests.
- Badge count semantics.
- A dedicated notification settings screen.
- Widget/App Group changes — Phase 4.

## Tests

Unit tests use Swift Testing (`QuestKeeperTests`).
The planner tests should not touch the real notification center.

1. **Deterministic identifiers** — the same quest id always yields exactly the due-soon and deadline identifiers.
2. **Past deadline skips scheduling** — a quest with `deadline <= now` returns no plans.
3. **Completed quest skips scheduling** — any non-nil `completedAt` returns no plans.
4. **Due-soon skip, deadline keep** — when `deadline - notificationLeadTime <= now < deadline`, the planner returns only the deadline request.
5. **Future quest schedules both** — when both fire dates are future, the planner returns due-soon and deadline in deterministic order.
6. **Calendar trigger content** — service builds non-repeating calendar requests with `questID` and `kind` in `userInfo`.
7. **Edit lifecycle removes before add** — fake center observes both deterministic identifiers removed before replacement requests are added.
8. **Completion cancellation** — fake center observes pending and delivered notifications removed for both identifiers.
9. **Reconcile removes stale requests** — pending QuestKeeper requests for missing/completed/past quests are removed.
10. **Reconcile schedules missing expected requests** — fake center starts empty and receives expected future plans when authorized.
11. **Denied permission does not fail save path** — service returns denied/skipped without throwing through the action boundary.
12. **Notification route parser** — valid `questID` routes, invalid/missing ids are ignored.

## Verification

1. Build:

```bash
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'
```

2. Unit tests:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests
```

3. Manual simulator flow:

```plaintext
1. Reset or deny notification permission for QuestKeeper.
2. Create a future quest.
3. Confirm the quest saves even if permission is denied.
4. Enable notifications in Settings and reopen the app.
5. Confirm activation reconcile schedules the expected future notifications.
6. Create a quest with a near-future deadline, then edit its deadline twice.
7. Confirm only one due-soon/deadline pair is pending for that quest.
8. Complete the quest before the deadline.
9. Confirm no later deadline notification fires for the completed quest.
10. Create another near-future quest and tap its delivered notification.
11. Confirm the app opens to the matching quest or its resolved read-only state.
```

4. Source guard:

```bash
grep -rnE '(notificationID|isNotificationScheduled|reminderEnabled|lastNotificationFiredAt)' QuestKeeper/Models/
```

Expected result: no matches.

## Open Questions

- **Lead time** — default is one hour. This is a tuning constant, not a stored preference.
- **Resolved quest tap UI** — default is a read-only resolution sheet or row highlight. Avoid reopening `QuestEditor` for graves/victories.
- **Permission denied affordance** — default is a small inline status near creation/active rows plus Settings deep link. No dedicated settings screen yet.
- **Sound** — default system sound. Custom sounds are polish and out of scope.
