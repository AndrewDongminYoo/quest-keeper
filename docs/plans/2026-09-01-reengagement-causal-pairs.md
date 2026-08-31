# Validate Causal Event Pairs Before Computing Reengagement Rates

Tracked as GitHub issue #51.
A defect against the report contract in `docs/specs/023-user-controlled-reengagement-reminders.md`; it amends no spec and mints no new spec number.

## The Defect

`ReengagementReminderReport.make` counts each event kind independently:

```swift
let permissionRequests = canonicalEvents.count { $0.name == .reengagementPermissionRequested }
let permissionGrants = canonicalEvents.count { $0.name == .reengagementPermissionGranted }
```

Nothing requires a successor to have a matching predecessor, so an orphan successor produces `achieved = 1, eligible = 0` while `dataQuality.status` stays `.complete`.

## Correction to the Issue Body

The issue proposes matching every pair by installation and action ID.
That is right for two of the three pairs and wrong for the third, and implementing it as written would ship a worse defect than the one it fixes.

Read at the call sites in `ContentView`:

| Pair                                                             | Shared identifier                                                  | Source                                           |
| ---------------------------------------------------------------- | ------------------------------------------------------------------ | ------------------------------------------------ |
| `permissionRequested` → `permissionGranted` / `permissionDenied` | `actionID`, one `UUID()` reused across the request and its outcome | `saveReengagementSettings`                       |
| `notificationOpened` → `notificationCompleted`                   | `attribution.actionID` and `attribution.questID`                   | `consumeNotificationRoute` and `complete(_:at:)` |
| `reminderEnabled` → `reminderDisabled`                           | **none** — each call passes a fresh `actionID: UUID()`             | `saveReengagementSettings`                       |

Enabling and disabling are separate user actions, minutes or days apart, so there is no single action to share an ID.
Matching that pair by action ID would leave every disable unmatched, pin `reminderDisableRate` at `0`, and force `dataQuality.status` to `.partial` on every report.

## Design

Two matching rules, chosen by what the recorder actually writes.

**Action-linked pairs** — permission and notification.
A successor is matched when an earlier event of the predecessor kind shares its `installationID` and action ID, and, for the notification pair, its `questID`.
The action ID is the trailing `:`-separated component of `deduplicationKey`, which `RetentionEventRecorder.record` builds as `"<name>:<installationID>:<keyComponent>"` — `keyComponent` is the action ID alone for the permission events and `"<questID>:<actionID>"` for the notification events, so the trailing component is the action ID in both shapes.

**Ordering-linked pair** — enable and disable.
A disable is matched when an earlier enable exists for the same `installationID`.
This is `RetentionReport`'s orphan-completion shape without the ID equality, which is the strongest link the recorded facts support.

`make` pools installations rather than grouping by them, unlike `RetentionReport`.
Both rules therefore carry `installationID` in their predicate instead of relying on an enclosing per-installation loop.
That keeps the change inside the existing single pass rather than restructuring the function for a report that, on a single device, has one installation anyway.

Ordering follows `RetentionReport`: "earlier" means earlier in the `eventOrdering` sort (`occurredAt`, then `id`), not strictly earlier in time, so events sharing an instant stay deterministic.

## Counting

- `eligible` keeps counting predecessors, unchanged.
- `achieved` counts only matched successors.
- Unmatched successors are counted per event name in a new `orphanCountsByEvent`, mirroring the existing `duplicateCountsByEvent`, and push `dataQuality.status` to `.partial`.

`ReengagementReminderReport.currentSchemaVersion` stays at `1`.
`ReengagementReminderStore.load` decodes before it checks the version, so a stored report written without the new field fails to decode and returns `nil` either way; bumping the version would change nothing a reader can observe.

## Fixtures

`ReengagementReminderReportTests` builds `deduplicationKey` values by hand (`"permission-request-1"`, `"opened-1"`) that never had the production shape.
Matching cannot work against them, so the fixtures move to the real format.
The format is built by one helper shared with the recorder rather than hand-formatted in the test, so a fixture cannot encode a shape the recorder has stopped writing.

## Verification

1. A matched run over all three pairs keeps today's rates and `dataQuality.status == .complete`.
2. An orphan grant (a `permissionGranted` whose request was never recorded) is excluded from `achieved`, counted in `orphanCountsByEvent`, and turns the status `.partial`.
3. A disable with no earlier enable is treated the same way, and a disable that follows an enable with a different `actionID` is still matched — the regression the issue body's rule would have introduced.
4. `xcodebuild test -only-testing:QuestKeeperTests -parallel-testing-enabled NO`.
