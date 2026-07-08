# Plan 004 — Local Notification Lifecycle Implementation

Status: implemented baseline; historical plan
Source spec: `docs/specs/004-local-notifications.md`
Depends on: Phase 2 implemented state (`docs/specs/003-crud-hero-view.md`)

Implementation note: this plan was executed by commit `87bc5a0 feat: implement local notification lifecycle`.
It describes the pre-pivot baseline notification implementation.
Do not use this as the next implementation plan after the rewritten `BLUEPRINT.md`; use the revised specs 002-004 and create a new plan for daily graves / retry tomorrow / pixel dungeon UI.

## Intent

Phase 3 adds local notifications as an OS side effect around existing quest facts.
The implementation should keep the game truth in derivation (`QuestSnapshot` + `now`) and make notification scheduling deterministic, repairable, and testable.

## Scope

In:

- notification permission handling;
- due-soon and deadline local notification planning;
- create/edit sync with remove-before-add semantics;
- complete/delete cancellation;
- activation-time repair pass;
- notification tap routing back to a quest;
- planner/service/routing tests.

Out:

- push notifications or backend delivery;
- badges;
- snooze or recurring reminders;
- per-quest custom reminder offsets;
- custom notification sounds;
- a dedicated notification settings screen;
- Widget/App Group changes.

## Success Criteria

1. Scheduling is deterministic and duplicate-safe.
   Verify with planner/service tests and by editing the same quest deadline twice on the simulator.
2. Completion and deletion remove pending and delivered notifications for the quest.
   Verify with fake-center tests and manual simulator delivery/cancellation checks.
3. Permission denial does not block saving a quest.
   Verify manually by denying notifications before creating a future quest.
4. Notification taps route to the matching quest or a safe resolved/missing fallback.
   Verify with routing tests and a manual delivered-notification tap.
5. No notification lifecycle state is persisted on `Quest`.
   Verify with the source guard in the spec.

## Action Items

[ ] Add notification tuning and value types.

- Edit `QuestKeeper/Derivation/GameBalance.swift` to add `notificationLeadTime`.
- Add `QuestKeeper/Notifications/QuestNotificationKind.swift`.
- Add `QuestKeeper/Notifications/QuestNotificationPlan.swift`.

[ ] Add the pure planner.

- Add `QuestKeeper/Notifications/QuestNotificationPlanner.swift`.
- Derive stable identifiers from `Quest.id`.
- Return no plans for completed or past-deadline quests.
- Skip the due-soon plan when its fire date has already passed, while keeping the deadline plan if still future.

[ ] Test the planner first.

- Add `QuestKeeperTests/QuestNotificationPlannerTests.swift`.
- Cover deterministic identifiers, completed quest skip, past deadline skip, due-soon skip, future quest schedules both, and deterministic ordering.

[ ] Add a fakeable notification-center boundary.

- Introduce the smallest protocol wrapper needed to test schedule/cancel/reconcile behavior.
- Keep it local to the notifications module.
- Do not add third-party dependencies.

[ ] Implement `QuestNotificationService`.

- Add `QuestKeeper/Notifications/QuestNotificationService.swift`.
- Implement authorization status mapping and lazy request behavior.
- Implement remove-before-add `sync(quest:now:)`.
- Implement `cancel(questID:)` for pending and delivered notifications.
- Implement `reconcile(quests:now:)` to remove stale QuestKeeper requests and schedule missing expected requests.

[ ] Add service tests.

- Add `QuestKeeperTests/QuestNotificationServiceTests.swift`.
- Use the fake center to assert remove-before-add ordering, completion cancellation, stale request cleanup, missing request scheduling, and denied-permission no-op behavior.

[ ] Wire SwiftUI save/complete/delete/activation paths.

- In `QuestEditor.save()`, sync notifications after insert/edit.
- In `ContentView.complete(_:)`, cancel notifications after writing `completedAt`.
- In `ContentView.delete(_:)`, capture the id and cancel notifications around deletion.
- In `ContentView.onBecameActive(now:)`, keep Phase 2 reconstruction ordering, then trigger reconcile.

[ ] Add notification tap routing.

- Add `QuestKeeper/Notifications/NotificationRouteStore.swift`.
- Add a `UNUserNotificationCenterDelegate` bridge or app delegate adapter.
- Register it in `QuestKeeperApp.swift`.
- Consume pending route state in `ContentView` after `@Query` loads.
- Open editable pending quests; use a read-only sheet or row highlight for resolved quests.

[ ] Add minimal permission-denied UI.

- Keep the affordance inline near creation or active quest rows.
- Use a Settings deep link.
- Avoid adding a dedicated notification settings screen in Phase 3.

[ ] Verify with automated checks.

```bash
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests
grep -rnE '(notificationID|isNotificationScheduled|reminderEnabled|lastNotificationFiredAt)' QuestKeeper/Models/
```

[ ] Verify manually on simulator.

```plaintext
1. Deny notification permission and create a future quest.
2. Confirm the quest saves and the UI exposes a quiet disabled-notification state.
3. Enable notifications in Settings and reopen the app.
4. Confirm activation reconcile schedules expected future notifications.
5. Edit the same future quest deadline twice.
6. Confirm only one due-soon/deadline pair remains pending.
7. Complete the quest before the deadline.
8. Confirm no later deadline notification fires.
9. Create another near-future quest and tap its delivered notification.
10. Confirm the app opens to the matching quest or safe resolved state.
```

## Risks

- `UNUserNotificationCenter` behavior is hard to unit test directly, so the fakeable boundary must stay small.
- Notification delivery is not guaranteed by iOS; app state must remain correct without delivery.
- Notification response routing can arrive before SwiftData query results are visible; route consumption must tolerate delayed lookup.
- Asking permission too early will feel like a cold-launch prompt. Keep the first prompt tied to saving a future quest.

## Open Questions

- Use row highlight or read-only sheet for resolved notification taps. Default: whichever is smaller when wiring the route.
- Inline denied-permission affordance location. Default: place it in the creation/active quest flow, not a separate screen.
