# Spec 002 — Data Model & Derivation Layer (Phase 1)

Status: implemented
Depends on: 001 (project setup — Swift 6, iOS-only)
Blocks: Phase 2 (task CRUD & hero view)

Implementation note: the project sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (Xcode 26 default), so
every type is `@MainActor` unless opted out.
The derivation layer must run off the main actor (widget timeline provider, background reconstruction),
so `Importance`, `QuestSnapshot`, `QuestOutcome`, `HeroState`, `HeroDerivation`, and `GameBalance` are
declared `nonisolated`; only `Quest` (`@Model`) and the UI stay main-actor-isolated.
Build and 8 derivation tests pass on the iOS 26.5 simulator, zero warnings.
Note: run unit tests scoped with `-only-testing:QuestKeeperTests` — the template `QuestKeeperUITests`
runner is flaky on this simulator ("server died") and is unrelated to Phase 1.

## Goal

Nail the storage/derivation boundary in code, logic only, no UI (per BLUEPRINT Phase 1).
Persist immutable raw facts; compute every gamification value (a quest's outcome, urgency, mob level, and the hero's victory/grave tally) at read time against the current clock.
The layer must be a **pure, deterministic** function of its inputs and compile clean under Swift 6 strict concurrency.

## Product model (settled)

The core loop is **counting today's small victories**, not survival:

- Complete a quest on time → an enemy is defeated → a **victory** (a small win).
- Miss a deadline → the hero keels over ("꿱") and **revives for the next quest** — death is a momentary event, never a lingering state.
- The permanent consequence of a miss is a **grave** left on that spot. Graves **cannot be deleted** — they are the enduring record of failure.
- There is **no hero HP / health**. The hero is always alive; the only persistent scoreboard is `victories` vs `graves`.
- Making the hero visibly stronger per victory (upgrades) is **deferred** (BLUEPRINT backlog); `victories` is tallied now so that feature can derive from it later.

## The Core Boundary (non-negotiable)

- **Stored (facts):** `deadline`, `completedAt`, `importance`, plus `id`/`title`.
  Nothing time-relative, nothing derived.
- **Derived (never stored):** a quest's `outcome` (pending/victory/grave), `urgency`, `mobLevel`, and the hero's `victories`/`graves` tallies.
  All are functions of `(facts, now)` — and, for "what died while away", `lastOpened`.

Guardrail restated: if a value can be recomputed from the facts and the clock, it must **not** be a stored property.
A source grep enforces this (see Verification).

## Design

### 1. Persistence — `Quest` (`@Model`)

Model type name is **`Quest`** (chosen deliberately to avoid colliding with Swift Concurrency's `Task`).

```swift
import Foundation
import SwiftData

@Model
final class Quest {
    var id: UUID
    var title: String
    var deadline: Date
    var completedAt: Date?
    var importance: Importance

    init(id: UUID = UUID(), title: String, deadline: Date, importance: Importance, completedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.deadline = deadline
        self.importance = importance
        self.completedAt = completedAt
    }
}

/// Stored raw fact — the *inherent* weight the user assigns, independent of time.
enum Importance: Int, Codable, CaseIterable, Sendable {
    case low = 1, medium = 2, high = 3
}
```

Stored id is an explicit `UUID` (not just SwiftData's `PersistentIdentifier`) so the same identity survives into the Phase 4 widget / App Group, which reads the store out-of-process.

### 2. The derivation seam — `QuestSnapshot` (Sendable value)

Derivation operates on a plain **`Sendable` value snapshot**, not on the `@Model` class.
Rationale — this is the load-bearing decision of the phase:

- SwiftData `@Model` instances are reference types bound to a `ModelContext` / main actor; passing them into pure logic fights Swift 6 concurrency and forces tests to spin up a `ModelContainer`.
- A value snapshot of just the raw facts *is* "저장은 사실만" expressed as a type, is trivially `Sendable`, and lets every derivation test run with hand-built inputs — no persistence, no clock injection tricks beyond passing `now`.

```swift
struct QuestSnapshot: Sendable, Identifiable, Equatable {
    let id: UUID
    let deadline: Date
    let completedAt: Date?
    let importance: Importance
}

extension Quest {
    var snapshot: QuestSnapshot {
        QuestSnapshot(id: id, deadline: deadline, completedAt: completedAt, importance: importance)
    }
}
```

All derivation functions below take `QuestSnapshot` (or arrays of it) plus a `now: Date`.
`title` is intentionally absent from the snapshot — it plays no part in derivation.

### 3. Quest-level derivation — `QuestOutcome` + `QuestSnapshot` extension

A quest resolves, purely as a function of its facts and `now`, into exactly one outcome.
Once it reaches `.victory` or `.grave` it stays there — the deadline moment fixes it, and a late completion does **not** convert a grave back into a victory (the hero already fell).

```swift
enum QuestOutcome: Sendable, Equatable {
    case pending   // deadline not yet passed, not completed
    case victory   // completed on time (completedAt <= deadline) — an enemy defeated
    case grave     // deadline passed without on-time completion — permanent
}

extension QuestSnapshot {
    var isCompleted: Bool { completedAt != nil }

    func outcome(at now: Date) -> QuestOutcome {
        if let completedAt {
            return completedAt <= deadline ? .victory : .grave   // late completion is still a grave
        }
        return deadline < now ? .grave : .pending
    }

    /// A grave is permanent and cannot be deleted; a pending or victorious quest can.
    /// (Phase 1 exposes the predicate; Phase 2's CRUD UI enforces it.)
    func isDeletable(at now: Date) -> Bool { outcome(at: now) != .grave }

    /// 0 … 1, rising as the deadline nears; only meaningful while `.pending` (0 otherwise).
    func urgency(at now: Date) -> Double {
        guard outcome(at: now) == .pending else { return 0 }
        let remaining = deadline.timeIntervalSince(now)
        if remaining >= GameBalance.urgencyHorizon { return 0 }
        return 1 - remaining / GameBalance.urgencyHorizon
    }

    /// Discrete mob tier = importance (stored) × urgency (derived), mapped into 0 … maxMobLevel.
    func mobLevel(at now: Date) -> Int {
        let raw = Double(importance.rawValue) * urgency(at: now)   // 0 … 3
        return Int((raw / 3.0 * Double(GameBalance.maxMobLevel)).rounded())
    }
}
```

### 4. Hero derivation — `HeroState` + `HeroDerivation.state(...)`

`HeroState` is a **derived value type**, never persisted.
It is a scoreboard, not a health meter: the hero is always alive.
The entry point keeps BLUEPRINT's signature `heroState(quests:now:lastOpened:)` and is deterministic in all three inputs.

```swift
struct HeroState: Sendable, Equatable {
    let victories: Int          // enemies defeated (on-time completions)
    let graves: Int             // permanent failures — monotonic over real time
    /// Quests whose deadline fell within (lastOpened, now] and resolved to a grave —
    /// drives the "꿱 → revive" moment shown on reopen. Independent of the tallies above.
    let deathsWhileAway: [UUID]
    // No hp, no isDead: death is an event (deathsWhileAway), not a state.
    // Strength-from-victories upgrade is deferred; derive it from `victories` later.
}

enum HeroDerivation {
    static func state(quests: [QuestSnapshot], now: Date, lastOpened: Date) -> HeroState {
        var victories = 0
        var graves = 0
        for quest in quests {
            switch quest.outcome(at: now) {
            case .victory: victories += 1
            case .grave:   graves += 1
            case .pending: break
            }
        }

        let deathsWhileAway = quests
            .filter { $0.deadline > lastOpened && $0.deadline <= now && $0.outcome(at: now) == .grave }
            .map(\.id)

        return HeroState(victories: victories, graves: graves, deathsWhileAway: deathsWhileAway)
    }
}
```

`graves` only ever grows as real time passes (deadlines pass, they never un-pass, and late completion keeps the grave), which is exactly the "un-erasable graveyard" the product wants — and it falls straight out of pure derivation, no stored death events, honoring BLUEPRINT's state-replay principle.

### 5. Tunable balance — `GameBalance`

Every game-balance number lives in one namespace so tuning never touches logic and never risks a stored-state migration (there is none — it is all derived).

```swift
enum GameBalance {
    static let maxMobLevel = 5
    static let urgencyHorizon: TimeInterval = 7 * 24 * 60 * 60   // 7 days
}
```

### 6. Schema registration

Add `Quest` to the app's `Schema` in `QuestKeeperApp.swift`.
For this phase `Quest` **coexists with the template `Item`** — do not delete `Item` yet.

```swift
let schema = Schema([Quest.self, Item.self])
```

## Files

- `QuestKeeper/Models/Quest.swift` — `@Model final class Quest`, `enum Importance`.
- `QuestKeeper/Models/QuestSnapshot.swift` — `QuestSnapshot` + `Quest.snapshot`.
- `QuestKeeper/Derivation/QuestOutcome.swift` — `enum QuestOutcome` + the `QuestSnapshot` extension (outcome, isDeletable, urgency, mobLevel).
- `QuestKeeper/Derivation/HeroDerivation.swift` — `HeroState`, `HeroDerivation`.
- `QuestKeeper/Derivation/GameBalance.swift` — constants.
- `QuestKeeper/QuestKeeperApp.swift` — register `Quest` in `Schema` (edit).
- `QuestKeeperTests/DerivationTests.swift` — Swift Testing suite (below).

## Out of Scope (deferred)

- Any UI, `@Query`, `scenePhase`, `TimelineView` — Phase 2.
  `ContentView` and `Item` stay untouched this phase; `Item` removal + hero/graveyard view come with Phase 2 (this supersedes the earlier note in spec 001 that placed `Item` removal in Phase 1 — it can only go once its `ContentView` consumer is rewritten).
- Enforcing "graves are undeletable" in the UI, and the "꿱 → revive" animation — Phase 2 (Phase 1 only exposes `isDeletable(at:)` and `deathsWhileAway`).
- Hero upgrades / getting visibly stronger per victory — BLUEPRINT backlog.
- Notifications — Phase 3.  Widget / App Group — Phase 4.

## Tests (Swift Testing, `QuestKeeperTests`)

All inputs are hand-built `QuestSnapshot` values with a fixed reference `now`; no `ModelContainer` needed.

1. **Determinism** — `HeroDerivation.state(...)` called twice with identical `(quests, now, lastOpened)` returns `==` results.
2. **Six-months-later reconstruction** — quests with deadlines in the past, `now` six months out, `lastOpened` also in the past: `victories`/`graves` match the facts exactly — proving state is rebuilt from facts alone, with zero reliance on intervening events.
3. **Outcome classification** — on-time completion → `.victory`; not completed and past deadline → `.grave`; late completion (`completedAt > deadline`) → `.grave`; not yet due → `.pending`.
4. **Graves are permanent & undeletable** — a `.grave` has `isDeletable == false`; a late completion keeps `.grave` (never flips to `.victory`); `.pending` and `.victory` have `isDeletable == true`.
5. **Urgency is monotonic while pending** — for one un-completed quest, `urgency(at:)` is non-decreasing as `now` advances toward the deadline, `0` before the horizon, approaching `1` at the deadline; once the quest becomes a `.grave`, `urgency == 0`.
6. **Mob level rises with urgency** — same quest, `mobLevel(at:)` non-decreasing as `now` advances toward the deadline; `high` importance never yields a lower tier than `low` at the same `now`.
7. **Victories count small wins** — completing a `.pending` quest on time increments `victories`; an un-completed or grave quest does not.
8. **`deathsWhileAway`** — a quest whose deadline fell in `(lastOpened, now]` and is now a grave appears; one that resolved to `.victory`, or whose deadline is outside the window, does not.
9. **No derived storage (guardrail)** — enforced by the grep guard in Verification #3, not a `Mirror` test: the `@Model` macro rewrites stored properties into computed accessors over `_$backingData`, so reflecting a `Quest` enumerates backing/observation internals rather than the declared fields. A source-level grep is the reliable enforcer; if a runtime assertion is wanted later, confirm what `Mirror(reflecting:)` actually yields on a `@Model` instance before trusting it.

## Verification

1. `xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'` → succeeds, zero warnings under Swift 6 / strict concurrency `complete`.
2. `xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'` → all nine tests pass.
3. Grep guard: `grep -rnE '(var|let) +(hp|isDead|mobLevel|urgency|victories|graves|outcome)' QuestKeeper/Models/` returns nothing (facts only; derived values live in the Derivation folder, never on the `@Model`).

## Open Questions (defaults chosen; all tunable without migration)

- **Un-completing a victory** — clearing a quest's `completedAt` reverts `.victory → .pending` (and it can fail later).
  This is inherent to deriving from the raw fact and is accepted as-is; the UI decides whether it even offers "un-complete".
- **Mob tier mapping** — default: `importance × urgency` normalized into `0…5`.
  Revisit the tier count once the hero/mob view exists and the numbers can be seen.
- **Graveyard growth** — un-deletable failed quests accumulate in the store indefinitely (by design — it is a graveyard).
  No cap in Phase 1; revisit only if store size ever becomes a real concern.
