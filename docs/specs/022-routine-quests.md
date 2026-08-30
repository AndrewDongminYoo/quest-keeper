# Daily Routine Quests

Tracked as Linear AND-115.

## Goal

Let users register small daily chores without turning them into ordinary deadline-driven monsters.
The home board shows at most two routine quests in a separate section.
Completing a routine hides it for the current local day and makes it eligible again on the next local day.

## Stored Facts

`RoutineRule` stores only the rule's `id`, title, and `createdAt`.
It is the durable user choice to repeat a small task daily.

`RoutineCompletion` is append-only and stores its `id`, `routineID`, `localDayKey`, `timeZoneIdentifier`, and `completedAt`.
It records one user completion fact for one routine on one local day.

`Quest`, `QuestSnapshot`, Daily Focus selections, notification facts, and widget payloads do not change.
No routine field is added to `Quest`.

Deleting a rule stops future presentation but does not delete its completion facts.
The first version has no history screen, so a renamed or deleted rule does not rewrite prior facts.

## Current-Day Semantics

The current day uses `DailyFocusDay.gregorianCalendar(timeZone:)` and `DailyFocusDay.key(for:calendar:)`.
The completion recorder accepts at most one row for a `(routineID, localDayKey)` pair.
Repeating the same completion request is idempotent.

`completedToday` is derived by matching the current local day key against completion facts.
There is no stored `isCompletedToday`, `hiddenUntil`, streak, or next-occurrence value.
At the next local calendar day, an old completion no longer hides the rule.

## Exposure Policy

The board selects a daily roster before it removes completed routines.
This prevents a newly selected chore from replacing one the user just completed.

Active rules are rules with `createdAt <= now`.
They sort by ascending `UUID.uuidString` and rotate by the local Gregorian day ordinal.
The first two IDs from that circular order form the roster.
The board then removes roster IDs completed on the current local day.

The result is deterministic for the same rules, completion facts, time, and calendar.
Creating or deleting a rule can change the current roster because the roster is deliberately derived rather than persisted.
Store a daily roster fact only if real use shows that this limited churn harms the experience.

Routine rows appear outside the ordinary Quest list and after the Daily Focus section.
They do not enter `DailyFocusState`, so they cannot occupy a recommended or confirmed focus slot.
They show no deadline, urgency, level, monster, grave, or notification state.
Their fixed low-stakes treatment is visual, not a stored importance field.

## Presentation And Management

The home board always exposes an add-routine action.
A native management sheet lists every rule and lets the user create, rename, or delete a rule.
The routine editor is title-only in this version.

Visible routine rows provide one accessible completion action.
Completing a row records the immutable completion fact and removes the row from the current board.
The management sheet remains available after all current-day rows have disappeared.

## Migration

The SwiftData schema adds `RoutineRule` and `RoutineCompletion` as new models.
Existing Quest rows remain unchanged and receive no conversion.
A migration test opens a store containing only the previous Quest schema and verifies that its facts remain intact while both new model collections are empty.

## Non-Goals

- Weekly, custom, or calendar-based recurrence.
- Streaks, rewards, a completion-history screen, undo, or editing completion facts.
- Notifications, widgets, App Intents, retention events, or automatic conversion of old quests.
- Adding routine rows to Daily Focus, Hero victories, Hall of Fame, graves, or the ordinary Quest detail flow.

## Verification

- Pure tests prove a two-row cap, input-order independence, deterministic daily rotation, same-day hiding without replacement, next-day re-entry, and local-day behavior across Asia/Seoul and a DST boundary.
- Recorder tests prove one immutable completion per routine and local day.
- Migration tests prove a previous Quest-only store opens with the new schema.
- UI tests create, complete, manage, and delete routines without changing the Daily Focus surface.
- Localization, focused routine tests, and the full `QuestKeeperTests` suite pass with parallel testing disabled.
