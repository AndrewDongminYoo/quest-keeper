# Spec 002 — Data Model & Derivation Layer (Phase 1)

Status: revision planned
Depends on: 001 (project setup — Swift 6, iOS-only)
Blocks: Phase 2 (task CRUD & positive dungeon UX)

Implementation note: the current code implements the pre-pivot Phase 1 baseline: `Quest`, `QuestSnapshot`, `QuestOutcome`, `HeroState`, and pure derivation compile under Swift 6 and pass tests.
This revised spec supersedes the old permanent-grave model.
Current code still exposes a total `graves` count and an undeletable grave guard; those are now drifted from `BLUEPRINT.md` and must be changed in the next implementation pass.

## Goal

Keep the storage boundary fixed while changing the game model from permanent failure monuments to a daily, forgiving dungeon.
Persist only raw facts.
Derive quest outcome, urgency, mob level, today's visible graves, total victories, and reopen death events from facts plus `now`.

## Product Model

- Complete a quest on time → enemy defeated → **victory**.
- Miss a deadline → show a temporary "꿱" / tombstone event in today's dungeon window.
- Yesterday's missed quest must not keep pressuring the user on the main screen.
- The hero has no stored HP, no stored `isDead`, and no permanent grave count.
- Victory count may be cumulative because it is derived from completed facts.
- Daily grave visibility is derived from the missed quest's deadline and `now`.
- "내일 도전하기" is a Phase 2 action that moves the quest back into the active dungeon by changing raw facts, not by storing a retry state.

## Core Boundary

Stored facts on `Quest`:

```swift
@Model
final class Quest {
    var id: UUID
    var title: String
    var deadline: Date
    var completedAt: Date?
    var importance: Importance
}
```

Derived values, never stored:

- `outcome`
- `urgency`
- `mobLevel`
- `totalVictories`
- `dailyGraves`
- `deathsWhileAway`
- monster kind / sprite tier
- retry eligibility

Guardrail:

```bash
! rg -n '(var|let) +(hp|isDead|mobLevel|urgency|victories|graves|outcome|retry|monster)' QuestKeeper/Models/
```

Expected result: no derived-state stored fields.

## Quest Outcome

`QuestOutcome` remains the quest-level classifier:

```swift
enum QuestOutcome: Sendable, Equatable {
    case pending
    case victory
    case grave
}
```

Rules:

- `completedAt <= deadline` → `.victory`
- `completedAt > deadline` → `.grave`
- `completedAt == nil && deadline < now` → `.grave`
- otherwise → `.pending`

Late completion is still a grave for derivation.
The UI may choose whether to expose late completion, but it must not convert a missed deadline into a victory.

## Daily Grave Visibility

Add a daily visibility rule separate from `outcome`:

```swift
extension QuestSnapshot {
    func isVisibleDailyGrave(at now: Date, calendar: Calendar = .current) -> Bool
}
```

Default:

- visible if `outcome(at: now) == .grave`;
- and the missed `deadline` is within the current local day or within `GameBalance.dailyGraveVisibilityWindow`;
- not counted as a permanent scoreboard.

Prefer current-local-day semantics for UI grouping.
Use a 24-hour rolling window only if local-day boundary behavior proves awkward in manual testing.

## Hero State

Replace the pre-pivot `graves: Int` with daily identifiers:

```swift
struct HeroState: Sendable, Equatable {
    let totalVictories: Int
    let dailyGraves: [UUID]
    let deathsWhileAway: [UUID]
}
```

Rules:

- `totalVictories` counts all `.victory` quests.
- `dailyGraves` contains only currently visible `.grave` quest IDs.
- `deathsWhileAway` contains missed quests whose deadline fell in `(lastOpened, now]`.
- `deathsWhileAway` drives the temporary "꿱" event; it is not a stored death state.

## Game Balance

Keep balance in `GameBalance`:

```swift
nonisolated enum GameBalance {
    static let maxMobLevel = 5
    static let urgencyHorizon: TimeInterval = 7 * 24 * 60 * 60
    static let mourningDuration: TimeInterval = 2
    static let notificationLeadTime: TimeInterval = 60 * 60
    static let dailyGraveVisibilityWindow: TimeInterval = 24 * 60 * 60
    static let longQuestWarningHorizon: TimeInterval = 7 * 24 * 60 * 60
}
```

Changing these values must not require a data migration.

## Retry Tomorrow Contract

Phase 2 owns the UI action, but Phase 1 should expose the pure helper:

```swift
nonisolated func retryDeadlineTomorrow(from now: Date, calendar: Calendar = .current) -> Date
```

Default behavior:

- set the new deadline to tomorrow at the same local time if practical;
- otherwise use tomorrow at a conservative default evening time;
- keep `importance`;
- clear `completedAt` if needed.

Do not store retry count in Phase 1.

## Files

- `QuestKeeper/Models/Quest.swift` — unchanged raw facts.
- `QuestKeeper/Models/QuestSnapshot.swift` — unchanged snapshot boundary.
- `QuestKeeper/Derivation/QuestOutcome.swift` — add daily grave visibility and retry eligibility helpers.
- `QuestKeeper/Derivation/HeroDerivation.swift` — replace total grave count with `dailyGraves`.
- `QuestKeeper/Derivation/GameBalance.swift` — add daily grave / chunking constants.
- `QuestKeeperTests/DerivationTests.swift` — update tests for daily reset and no permanent grave count.

## Tests

1. **No derived storage** — source guard returns no matches in `QuestKeeper/Models/`.
2. **Outcome classification** — pending, victory, grave, and late-grave still classify deterministically.
3. **Daily grave visibility** — a grave from today is visible; yesterday's grave is not visible in the main dungeon.
4. **Hero state has no permanent grave count** — total victories persist, daily graves reset by date/window.
5. **Deaths while away** — only missed deadlines in `(lastOpened, now]` appear.
6. **Urgency and mob level** — still rise from stored `importance` and derived time remaining.
7. **Retry tomorrow helper** — produces a future deadline without storing retry state.

## Verification

```bash
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests
! rg -n '(var|let) +(hp|isDead|mobLevel|urgency|victories|graves|outcome|retry|monster)' QuestKeeper/Models/
```

## Open Questions

- `BLUEPRINT.md` says missed facts remain in DB, but "내일 도전하기" overwrites `deadline`.
  With the current raw-facts-only model, overwriting the deadline loses the original missed deadline.
  Default for the next implementation pass: accept that tradeoff and avoid a history model.
- Daily grave visibility should use local calendar day or rolling 24 hours.
  Default: local calendar day for emotional reset.
