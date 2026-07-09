# Spec 006 — Integration Verification & Retrospective (Phase 5)

Status: planned
Depends on: 005 (home-screen widget), implemented daily dungeon pivot, implemented local notification lifecycle
Blocks: first learning milestone closeout

## Goal

Prove the QuestKeeper native learning slice works as one deterministic system across SwiftData facts, derived dungeon state, local notifications, app activation, and the Home Screen widget.
Phase 5 should not add a new product surface.
It should turn the already-built OS-boundary work into repeatable verification evidence and a short retrospective that captures what was learned.

## Phase 5 Decision

Use a **verification-closeout phase**, not a polish or feature-expansion phase.

The BLUEPRINT goal is confidence that the app can cross native iOS boundaries without a bridge:

- local persistence through SwiftData;
- time-relative reconstruction after app inactivity;
- local notification schedule, cancellation, delivered-alert pruning, and reconcile;
- App Group snapshot writing;
- WidgetKit rendering from a read-only cache.

Those pieces are implemented across previous phases.
The next risk is not missing UI polish.
The next risk is drift between surfaces, undocumented manual assumptions, and no single evidence trail showing that the full lifecycle works.

## Scope

In scope:

- cross-surface automated tests that compare app derivation and widget derivation from the same raw facts;
- automated checks that retry tomorrow, completion, deletion, notification sync, activation replay, and widget snapshot payloads stay aligned;
- source-level invariant checks that `Quest` continues to store only raw facts;
- a manual simulator/device checklist for notification and widget behavior that cannot be fully proven by unit tests;
- a short retrospective note summarizing the native iOS boundaries crossed, unresolved limits, and follow-up backlog.

Out of scope:

- new gameplay mechanics;
- SpriteKit or real pixel-art asset production;
- CloudKit, login, backend, sync, or multi-device support;
- recurring quests;
- interactive widgets or AppIntent actions;
- migrating SwiftData into the App Group container.

## System Invariants

Stored `Quest` facts remain exactly:

```swift
var id: UUID
var title: String
var deadline: Date
var completedAt: Date?
var importance: Importance
```

The model must not store:

- HP;
- `isDead`;
- grave count;
- retry count;
- monster type;
- urgency;
- mob level;
- notification identifiers;
- notification scheduled state;
- widget identifiers;
- widget-derived state.

The app, notifications, and widget may all observe or cache derived state, but the canonical truth remains raw quest facts plus the current clock.

## Automated Verification Requirements

### Cross-Surface Derivation

Given the same quest facts and the same clock:

- `HeroDerivation.state` and `WidgetDungeonDerivation.derive` must agree on total victories;
- visible daily graves must refer to the same missed quests for the current local day;
- old missed quests must not appear in either the app's daily grave list or the widget's daily grave list;
- late completions must not become victories and must not render as active mobs;
- late completions remain graves, so if their deadline is on the current local day they must appear as daily graves in both app and widget derivation.

### Lifecycle Integration

The automated tests should cover these user journeys without relying on UI automation:

1. Create a pending quest.
   It appears in the widget payload and schedules future notifications.
2. Complete the quest on time.
   It remains stored as a raw fact, contributes to victories, is excluded from active mobs, cancels notifications, and updates the widget payload.
3. Miss a quest and retry tomorrow.
   The deadline moves to tomorrow, `completedAt` clears, notifications resync, visible daily grave pressure disappears, and the widget sees the quest as active again.
4. Delete a quest.
   The quest is removed from the widget payload and notification identifiers are canceled.
5. Reopen after time passed.
   `reconstructOnActivation` reports deaths only once and advances the stored activation clock.

### Source Guard

The verification phase must include a repeatable command that fails the review if forbidden derived fields appear under `QuestKeeper/Models`.
The minimum guard is:

```bash
! rg -n '^\s*(?:@\w+(?:\([^)]*\))?\s*)*(?:private|fileprivate|internal|public|package|open)?\s*(?:var|let)\s+(?:[Hh][Pp]|isDead|graveCount|retryCount|notificationID|isNotificationScheduled|widgetID|mobLevel|monsterType|urgency)\b' QuestKeeper/Models
```

Expected result: no output and exit code 0.

## Manual Verification Requirements

Some iOS system behavior is not reliable to assert in unit tests.
Phase 5 must create and fill a manual verification log under `docs/notes/`.

The log must record:

- device or simulator name and OS version;
- app build source commit;
- notification authorization state;
- App Group/widget installation status;
- each scenario's observed result;
- any limitation where WidgetKit refresh timing or notification delivery timing is controlled by the OS.

Required manual scenarios:

1. Fresh install and first launch.
   The app opens without seeded state, can request notification permission, and renders an empty safe dungeon.
2. Create due-soon and later quests.
   Pending notification requests exist and the widget shows active mobs after timeline reload or normal refresh.
3. Edit a deadline.
   Old notification identifiers are removed before replacements are scheduled.
4. Complete a quest.
   Pending and delivered QuestKeeper notifications are removed, the victory count rises, and the widget no longer shows the quest as active.
5. Retry tomorrow.
   The quest returns to the active dungeon with a tomorrow deadline, notification requests are recreated for the new deadline, and the widget snapshot updates.
6. Delete a quest.
   Notifications and widget payload entries for that quest disappear.
7. App reopen after missed deadline.
   The transient death/replay event appears only once, and old missed quests are not displayed as permanent pressure.

## Retrospective Requirements

Create a short retrospective note under `docs/notes/`.
It should answer:

- Which native iOS boundaries were crossed in this milestone?
- Which boundary was most error-prone?
- Which assumptions were verified only manually?
- Which shortcuts are acceptable for the learning milestone?
- Which backlog item should come next after the closeout?

The retrospective should be factual, not celebratory marketing copy.
It should record evidence and tradeoffs that are useful for the next development phase.

## Testing Commands

Automated verification:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'
git diff --check
! rg -n '^\s*(?:@\w+(?:\([^)]*\))?\s*)*(?:private|fileprivate|internal|public|package|open)?\s*(?:var|let)\s+(?:[Hh][Pp]|isDead|graveCount|retryCount|notificationID|isNotificationScheduled|widgetID|mobLevel|monsterType|urgency)\b' QuestKeeper/Models
```

The source-guard command is expected to print no matches and exit 0 because `!` inverts `rg`'s no-match exit status.

## Acceptance Criteria

- A Phase 5 automated integration test file exists and passes under `QuestKeeperTests`.
- The automated tests compare app derivation and widget derivation from the same raw quest facts.
- The notification and widget lifecycle expectations are covered by tests or the manual verification log.
- The source guard shows no forbidden derived fields in `QuestKeeper/Models`.
- `QuestKeeperTests` pass on the `iPhone 17e` simulator.
- The app builds for the `iPhone 17e` simulator with Swift 6 strict concurrency.
- `docs/notes/006-phase-5-verification-log.md` records the manual verification evidence.
- `docs/notes/006-phase-5-retrospective.md` records the learning closeout and follow-up backlog.
- No third-party dependencies are added.
