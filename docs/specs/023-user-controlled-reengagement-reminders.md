# Spec 023 — User-Controlled Reengagement Reminders

Status: approved for implementation
Tracks: AND-38

## Goal

Let a person choose an optional local reminder that brings them back to one relevant unfinished quest.
The feature must preserve the existing deadline-reminder lifecycle and must not request notification permission before a first quest is saved.

## Product Decisions

The first value boundary is the first valid `quest_created` event, as defined by Spec 012.
The reminder settings entry point is visible from the dungeon board, but enabling is unavailable until at least one quest exists.
Notification permission is requested only after the person explicitly enables a valid reminder configuration.
Creating, editing, retrying, or opening a quest never requests permission.

The configuration is local-only and defaults to disabled.
It contains an enabled state, a time of day, a daily or weekdays-only frequency, optional quiet hours, and a reminder purpose.
The default time is 20:00.
The default frequency is daily.
The default purpose is to finish one unfinished quest.
Quiet hours are enabled by default from 22:00 to 08:00.

The supported purposes are `finishOneQuest` and `reviewPlan`.
They select different fixed, privacy-safe copy and never include a quest title, details, or other user-entered content.
An enabled configuration whose selected time falls inside quiet hours remains saved but schedules no reminder until the person changes it.

## Target Selection

Only a quest with derived outcome `.pending` can be a reengagement target.
Completed quests and daily graves are excluded.
The target order is nearest deadline, then higher importance, then ascending UUID string.
This release uses an unfinished quest because Daily Focus is dormant in ordinary production execution.
When Daily Focus is deliberately enabled for ordinary execution, it may become a preferred eligible target without changing the settings contract.

## Scheduling And Identity

`ReengagementReminderPlanner` is pure and receives snapshots, settings, the current time, and a calendar.
It emits one repeating request for daily frequency or five repeating requests for weekdays-only frequency.
The identifiers are deterministic and live under the `reengagement.` prefix.
The daily identifier is `reengagement.daily`.
Weekday identifiers are `reengagement.weekday.<weekday>`.

Every reconfiguration and app activation performs remove-before-add reconciliation for both `quest.` and `reengagement.` requests.
The notification service removes delivered reengagement requests during reconciliation too.
The target UUID and `kind = reengagement` travel in notification user info.
The service reserves one platform slot for a daily reminder or five slots for weekdays-only reminders before it plans deadline requests.
The existing 64-request limit therefore remains deterministic, and reengagement requests do not evict unrelated deadline requests after they are added.

## Permission And Error Handling

Turning on a valid configuration checks authorization inside the settings save flow.
If authorization is not determined, the app records the request action and asks the system for permission.
Allowed, denied, and unavailable results leave the configuration intact.
Denied permission presents the existing system-settings route.
Permission and scheduling failures never block quest creation, editing, completion, retry, or deletion.

## Tap Routing And Measurement

Tapping a reengagement notification routes to its target quest detail screen when that quest is still available.
The route falls back to the board when the target is no longer resolvable.
A resolved route creates one in-memory attribution for the current foreground execution.
Completing that same quest before the app enters the background records the attributed completion.

The local retention event dictionary adds these app-source events:

- `reengagement_permission_requested`;
- `reengagement_permission_granted`;
- `reengagement_permission_denied`;
- `reengagement_reminder_enabled`;
- `reengagement_reminder_disabled`;
- `reengagement_notification_opened` with a quest UUID;
- `reengagement_notification_completed` with the same quest UUID.

Each user action has a UUID-based deduplication component.
`ReengagementReminderReport` computes these local rates from canonical events:

- permission grant rate = granted / requested;
- disable rate = disabled / enabled;
- notification completion rate = attributed completed / resolved opened.

The report is written atomically as `reengagement-reminder-v1.json` with the existing activation reports.
It stores no notification text, quest title, details, or account identifier.

## Scope Boundaries

This work does not change quest facts, outcome derivation, the widget payload, accounts, remote analytics, push notifications, or the late-completion semantics tracked separately in AND-159.
The widget can complete a quest while the app is inactive.
The app repairs a changed reengagement target on its next activation, and a stale notification tap safely falls back to the board.

## Acceptance Criteria

- A fresh installation can create a quest without a system notification prompt.
- After a quest exists, the person can configure time, frequency, quiet hours, and purpose before explicitly enabling reminders.
- Enabling a valid configuration is the only route that requests authorization.
- Daily and weekday schedules use stable identifiers and no duplicate same-intent requests remain after repeated saves or activation.
- A reengagement notification contains only privacy-safe fixed copy and routes to its current target when it remains pending.
- Existing deadline notifications stay within the platform cap when reengagement reminders are enabled.
- The three local metrics are persisted and reproducible from event fixtures.
- AND-159 behavior is unchanged.

## Verification

Pure and service tests cover quiet-hour validation, deterministic target selection, daily and weekday identifiers, settings persistence, cap reservation, repeated reconciliation, authorization paths, and no-prompt editor sync.
Routing tests cover reengagement attribution and a stale target fallback.
Report tests cover each numerator, denominator, deduplication rule, and empty denominator.
UI checks cover the first-quest gate, the settings controls, and the denied-permission settings route.
Run `bash scripts/test-localization.sh` after adding user-facing strings.

## Oracle Precedent

[no precedent found]
The Oracle found no project-specific precedent for user-controlled reengagement notification timing or deterministic reconciliation, so this specification follows the current requirements and the existing notification lifecycle.
