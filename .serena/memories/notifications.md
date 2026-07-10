# Notifications & Widget

Local notifications and the widget are side effects around stored facts — never sources of truth (no notification/widget IDs on `Quest`).

## Local notifications (`QuestKeeper/Notifications/`)

- `QuestNotificationService` — service class; `QuestNotificationCenter` protocol with `SystemQuestNotificationCenter` (wraps `UNUserNotificationCenter`) — protocol seam for test injection. `QuestNotificationAuthorization` enum.
- `QuestNotificationPlanner` (enum) — pure planning: given quests + `now`, computes desired pending requests (due-soon + deadline). `QuestNotificationPlan`, `QuestNotificationKind`.
- Lifecycle: remove-before-add sync; completion/delete cancels; retry-tomorrow reschedules; activation reconciles pending vs desired. Uses `UNCalendarNotificationTrigger`.
- `NotificationDelegate` + `NotificationRouteStore` — tap routing.
- Copy is informational, never shame-based.

## Widget (`QuestKeeperWidget/` + `QuestKeeperShared/`)

- App writes an App Group JSON snapshot via `QuestKeeper/WidgetSupport/WidgetDungeonSnapshotWriter.swift` (maps quests → `WidgetDungeonPayload`), stored by `WidgetDungeonSnapshotStore` under app group `group.kr.donminzzi.QuestKeeper`.
- Widget reads the snapshot read-only, renders `systemSmall`/`systemMedium` dungeon; refresh triggered by WidgetKit after app mutations.
- Timeline policy tested in `WidgetTimelinePolicyTests`.

Tests: `QuestNotificationServiceTests`, `QuestNotificationPlannerTests`, `NotificationRoutingTests`, `WidgetDungeonPayloadTests`, `WidgetDungeonSnapshotStoreTests`, `WidgetDungeonSnapshotWriterTests`, `WidgetTimelinePolicyTests`.
