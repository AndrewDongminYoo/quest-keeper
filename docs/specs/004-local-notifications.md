# Spec 004 — Local Notification Lifecycle (Phase 3)

Status: implemented baseline; retry-tomorrow revision planned
Depends on: 003 (positive dungeon UX)
Blocks: Phase 4 (home-screen widget)

Implementation note: the current code implements the baseline local notification lifecycle:
deterministic identifiers, due-soon/deadline planning, permission handling, remove-before-add sync, completion/delete cancellation, activation reconcile, and notification tap routing.
That baseline passed `QuestKeeperTests` and `build_sim`.
This revised spec adds the new BLUEPRINT requirement: **"내일 도전하기" must cancel and re-register notifications**.

## Goal

Keep local notifications as an OS side effect around raw quest facts.
The scheduler must follow the quest lifecycle:

- create/edit → schedule or resync;
- complete → cancel;
- retry tomorrow → cancel old requests and schedule new future requests;
- activation → repair stale/missing requests;
- tap → route to the matching quest.

Notifications must never become the source of game truth.
If a notification never fires, the next app open still derives the correct dungeon state from stored facts.

## Core Rule

Do not store notification lifecycle state on `Quest`.

Allowed stored facts remain:

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
- `retryCount`
- HP / death / urgency / mob-level state

Notification identifiers are deterministic:

```swift
quest.<quest-id>.dueSoon
quest.<quest-id>.deadline
```

## Permission Flow

Default: request authorization lazily, when the user first saves a future-deadline pending quest.

Status handling:

- `.notDetermined` — request `alert` + `sound` only from create/edit save, not from activation repair.
- `.authorized`, `.provisional`, `.ephemeral` — schedule normally.
- `.denied` — save the quest, skip scheduling, and show a restrained Settings affordance.
- `@unknown default` — treat as unavailable and log.

Do not request badge permission in Phase 3.

## Notification Kinds

Each pending quest may have two notifications:

1. **Due soon** — `deadline - GameBalance.notificationLeadTime`
2. **Deadline** — `deadline`

Scheduling rules:

- If `completedAt != nil`, schedule nothing.
- If `deadline <= now`, schedule nothing.
- If due-soon fire date is already past, skip due-soon and keep deadline if still future.
- Use non-repeating `UNCalendarNotificationTrigger`.
- Include `questID` and `kind` in `userInfo`.

Recommended copy:

- Due soon title: `퀘스트 마감 임박`
- Due soon body: `<title> · 곧 마감됩니다`
- Deadline title: `퀘스트 마감`
- Deadline body: `<title> 마감 시간이 되었습니다`

Do not say:

- `무덤이 생겼습니다`
- `실패했습니다`
- `용사가 죽었습니다`

The dungeon can show a dramatic miss after app reopen, but notification copy stays informational.

## Lifecycle

### Create / Edit

```plaintext
save Quest fact -> request/check authorization -> remove pending + delivered old identifiers -> add current plans
```

Remove-before-add is mandatory.
The service must be serialized enough that rapid edits cannot re-add an older deadline after a newer edit.

### Complete

```plaintext
write completedAt -> remove pending + delivered dueSoon/deadline notifications
```

Completion writes a fact.
It does not delete the quest.

### Retry Tomorrow

`retryTomorrow` is the new Phase 3 requirement.
It is triggered after Phase 2 mutates the quest deadline back into the future.

```plaintext
write new deadline + clear completedAt -> remove old pending + delivered identifiers -> add current future plans
```

Implementation contract:

```swift
QuestActions.retryTomorrow(...)
await QuestNotificationService.sync(quest: quest, now: now)
```

Do not add a separate notification method just for retry.
After retry, the quest is just a pending future quest again, so the existing sync path should own the lifecycle.

### Delete

```plaintext
delete Quest -> remove pending + delivered notifications
```

Delete is not the normal recovery path for daily graves.
The main recovery action is retry tomorrow.

### Activation Repair

On `.active`, after state replay:

- fetch pending notification identifiers;
- compute expected identifiers for current pending future quests;
- remove stale QuestKeeper requests;
- schedule missing requests only when permission is already allowed.

Do not show the iOS authorization prompt from activation repair.

## Notification Tap Routing

Every request carries:

```swift
[
    "questID": quest.id.uuidString,
    "kind": kind.rawValue
]
```

Routing contract:

- `UNUserNotificationCenterDelegate` extracts `questID`.
- A main-actor route store holds the pending id.
- `ContentView` consumes it after `@Query` contains the quest.
- If the quest is pending, open the edit/detail flow.
- If the quest is a visible daily grave, open the daily grave/retry surface.
- If the quest is a victory or old hidden grave, show a read-only state or highlight if available.
- If the quest never appears, log and leave no stored route state.

Do not add a custom URL scheme for Phase 3.

## Design

### Pure Planner

```swift
nonisolated enum QuestNotificationPlanner {
    static func identifiers(for questID: UUID) -> [String]
    static func plans(for snapshot: QuestSnapshot, title: String, now: Date) -> [QuestNotificationPlan]
}
```

The planner knows only raw facts and `now`.
It does not know about SwiftData, the UI, or authorization state.

### Service

```swift
@MainActor
final class QuestNotificationService {
    func authorizationStatus() async -> QuestNotificationAuthorization
    func requestAuthorizationIfNeeded() async -> QuestNotificationAuthorization
    func sync(quest: Quest, now: Date) async -> QuestNotificationAuthorization
    func cancel(questID: UUID) async
    func reconcile(quests: [Quest], now: Date) async -> QuestNotificationAuthorization
}
```

Requirements:

- convert `Quest` to `(snapshot, title)` immediately;
- remove pending and delivered notifications during sync;
- serialize notification operations enough to avoid stale rapid-edit schedules;
- keep failures non-blocking for quest save.

### SwiftUI Integration

Integration points after the Phase 2 revision:

- `QuestEditor.save()` → `sync`
- `QuestActions.complete` caller → `cancel`
- `QuestActions.retryTomorrow` caller → `sync`
- delete caller → `cancel`
- activation replay caller → `reconcile`
- notification tap route → edit/detail/daily-grave surface

Keep `QuestActions` focused on fact mutations.
Do not put `UserNotifications` in derivation.

## Files

Existing baseline files:

- `QuestKeeper/Notifications/QuestNotificationKind.swift`
- `QuestKeeper/Notifications/QuestNotificationPlan.swift`
- `QuestKeeper/Notifications/QuestNotificationPlanner.swift`
- `QuestKeeper/Notifications/QuestNotificationService.swift`
- `QuestKeeper/Notifications/NotificationRouteStore.swift`
- `QuestKeeper/Notifications/NotificationDelegate.swift`
- `QuestKeeper/QuestKeeperApp.swift`
- `QuestKeeper/ContentView.swift`
- `QuestKeeper/Views/QuestEditor.swift`

Revision files after Phase 2 retry action lands:

- `QuestKeeper/Actions/QuestActions.swift` — add retry action.
- `QuestKeeper/ContentView.swift` or `DungeonBoardView.swift` — call sync after retry.
- `QuestKeeperTests/QuestNotificationServiceTests.swift` — add retry resync coverage.

## Tests

Baseline tests to keep:

1. deterministic identifiers;
2. past deadline skips scheduling;
3. completed quest skips scheduling;
4. due-soon skip / deadline keep;
5. future quest schedules both;
6. calendar trigger content;
7. remove-before-add sync;
8. completion cancellation;
9. reconcile removes stale requests;
10. reconcile schedules missing expected requests;
11. denied permission does not fail save path;
12. route parser.

New retry tests:

13. **Retry tomorrow resync** — after retry moves a deadline future, fake center observes pending/delivered old IDs removed and new due-soon/deadline requests added.
14. **Retry does not prompt from activation** — activation repair schedules only if authorization is already allowed.
15. **Retry rapid edit safety** — latest retry/edit deadline wins for deterministic identifiers.

## Verification

```bash
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests
! rg -n '(notificationID|isNotificationScheduled|reminderEnabled|lastNotificationFiredAt|retryCount)' QuestKeeper/Models/
```

Manual simulator flow:

```plaintext
1. Deny notification permission and create a future quest.
2. Confirm the quest saves.
3. Enable notifications and reopen.
4. Confirm activation reconcile repairs expected future notifications.
5. Miss a near-future quest and reopen.
6. Tap "내일 도전하기".
7. Confirm old pending/delivered notifications are gone and new future notifications are scheduled.
8. Complete the retried quest.
9. Confirm no later deadline notification fires.
```

## Out of Scope

- Push notifications.
- Badge count.
- Snooze.
- Recurring quests.
- Custom sounds.
- Widget/App Group storage migration.
- LLM-generated notification text.
