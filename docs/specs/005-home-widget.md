# Spec 005 — Home Screen Widget (Phase 4)

Status: planned
Depends on: 004 (local notification lifecycle), daily dungeon pivot
Blocks: Phase 5 (integration verification)

## Goal

Show today's remaining mobs on the iOS Home Screen without opening the app.
The widget must reflect the same raw quest facts and derived dungeon rules as the app:

- pending future quests appear as active mobs;
- completed quests contribute to the victory tally;
- missed quests may appear as today's daily graves only when they are still visible by derivation;
- old missed quests do not keep pressuring the user.

The widget is a read-only system surface. It must not become a second source of truth.

## Phase 4 Decision

Use an **App Group JSON snapshot bridge** for the MVP.

The BLUEPRINT originally names "move SwiftData store into the shared App Group container."
That is a valid later migration, but it creates schema, target-membership, and migration risk before the widget's product behavior is proven.
For Phase 4, the app remains the only SwiftData writer and writes a small Codable snapshot into the App Group container.
The widget reads that snapshot and derives display state from `deadline`, `completedAt`, and `importance` at timeline render time.

This keeps the OS boundary explicit:

```plaintext
SwiftData facts in app -> Codable App Group snapshot -> WidgetKit timeline entry -> derived widget UI
```

## App Group

Use this App Group identifier unless the Apple Developer portal requires a different value:

```plaintext
group.kr.donminzzi.QuestKeeper
```

Targets that need the App Group entitlement:

- `QuestKeeper`
- `QuestKeeperWidget`

The widget extension bundle identifier should be:

```plaintext
kr.donminzzi.QuestKeeper.Widget
```

## Data Contract

The App Group file is a cache, not durable game state.
If the file is missing, unreadable, or uses an unsupported schema version, the widget renders an empty dungeon state instead of crashing.

File name:

```plaintext
widget-dungeon-snapshot.json
```

Payload shape:

```swift
struct WidgetDungeonPayload: Codable, Sendable, Equatable {
    var schemaVersion: Int
    var generatedAt: Date
    var quests: [WidgetQuestPayload]
}

struct WidgetQuestPayload: Codable, Sendable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var deadline: Date
    var completedAt: Date?
    var importanceRawValue: Int
}
```

`title` is included because the widget is a UI surface.
Game state is still derived from raw facts; do not persist `mobLevel`, `outcome`, `urgency`, `isDead`, retry count, grave count, or notification identifiers.

## Snapshot Writing

The app writes the snapshot after every quest mutation that can affect widget display:

- create
- edit
- complete
- uncomplete
- retry tomorrow
- delete
- app activation after state replay/reconciliation

The write should be atomic:

```plaintext
encode JSON -> write to temporary file -> replace widget-dungeon-snapshot.json
```

The write must not block saving a quest.
If the App Group container is unavailable on Simulator or in a signing-misconfigured build, log the failure and continue.

## Widget Derivation

The widget derives a display entry from payload plus `entryDate`.
It must not open the SwiftData store.

Derived entry fields:

- `activeMobs`: pending quests sorted by earliest deadline, limited for each widget family;
- `dailyGraves`: missed quests where `deadline` is on the current local day;
- `totalVictories`: count of quests with `completedAt != nil`;
- `isStale`: `generatedAt` is older than a conservative threshold such as 24 hours.

Urgency and mob level remain a function of time:

```plaintext
mob level = importance x urgency(at: entryDate)
```

WidgetKit does not guarantee second-by-second live updates.
The widget should provide timeline entries around meaningful threshold changes and use system-supported relative date text where useful.
Do not rely on the widget running app-like timers.

## Timeline Policy

The provider reads the App Group payload and creates entries for:

- now;
- the next due-soon threshold when a pending mob will visually intensify;
- the next deadline when a pending mob becomes a daily grave;
- a fallback refresh after 15 minutes when no threshold is sooner.

Clamp generated timeline entries to a small count for the MVP.
The provider should prefer predictable correctness over aggressive refresh frequency.

## Widget Families

MVP families:

- `systemSmall`: hero/victory HUD plus the single most urgent active mob.
- `systemMedium`: hero/victory HUD plus up to three active mobs and today's visible daily graves if there is space.

Out of scope for Phase 4:

- `systemLarge`
- lock screen widgets
- StandBy
- interactive widget actions
- AppIntent completion/retry buttons
- Live Activities

## UI Direction

The widget should match the new Quest Keeper direction:

- dark pixel-dungeon HUD;
- compact, glanceable rows;
- active mobs shown by title, urgency, and small visual level cue;
- no shame copy in the widget;
- old graves hidden by derivation;
- empty state should feel safe, not accusatory.

Recommended copy:

- empty active state: `던전이 조용합니다`
- stale snapshot state: `앱을 열면 던전이 갱신됩니다`
- mob deadline label: system relative time or short Korean remaining-time text

## Error Handling

Failure mode behavior:

- App Group URL missing: app logs and skips write; widget renders empty state.
- JSON missing: widget renders empty state.
- JSON corrupt: widget renders empty state and schedules normal fallback refresh.
- Unsupported schema version: widget renders empty state.
- Empty quest list: widget renders empty state.

No failure path should write derived game state back into SwiftData.

## Testing Requirements

Unit-level tests:

- payload encodes and decodes dates, UUIDs, titles, and importance raw values;
- widget derivation counts victories from `completedAt`;
- pending quests become active mobs at `entryDate`;
- old missed quests are hidden when not on the local day;
- today's missed quests appear as daily graves;
- snapshot store reads a valid payload from an injected file URL;
- snapshot store returns an empty result for missing or corrupt files;
- timeline scheduling picks the next meaningful deadline/threshold when available.

Project-level verification:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'
```

Manual verification:

1. Install the app on Simulator or device.
2. Create pending quests with near and later deadlines.
3. Add the QuestKeeper widget to the Home Screen.
4. Confirm pending mobs appear without opening the app again.
5. Complete or retry a quest in the app.
6. Confirm the widget updates after `WidgetCenter.reloadAllTimelines()` and normal WidgetKit refresh.

## Acceptance Criteria

- `Quest` still stores only raw facts: `id`, `title`, `deadline`, `completedAt`, `importance`.
- The widget target exists and builds with the app.
- App and widget targets share the App Group entitlement.
- The app writes `widget-dungeon-snapshot.json` into the App Group container after quest mutations.
- The widget reads the snapshot without importing or opening SwiftData.
- Derived widget display matches app derivation for pending mobs, victories, and daily graves.
- Missing or corrupt snapshot data does not crash the widget.
- No third-party dependencies are added.
