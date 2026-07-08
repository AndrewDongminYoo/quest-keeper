# Spec 002 — Data Model & Derivation Layer (Phase 1)

Status: proposed
Depends on: 001 (project setup — Swift 6, iOS-only)
Blocks: Phase 2 (task CRUD & hero view)

## Goal

Nail the storage/derivation boundary in code, logic only, no UI (per BLUEPRINT Phase 1).
Persist immutable raw facts; compute every gamification value (urgency, mob level, hero HP/death) at read time against the current clock.
The layer must be a **pure, deterministic** function of its inputs and compile clean under Swift 6 strict concurrency.

## The Core Boundary (non-negotiable)

- **Stored (facts):** `deadline`, `completedAt`, `importance`, plus `id`/`title`.
  Nothing time-relative, nothing derived.
- **Derived (never stored):** `urgency`, `mobLevel`, hero `hp`, `isDead`.
  All are functions of `(facts, now)` — and, for "what changed while away", `lastOpened`.

Guardrail restated: if a value can be recomputed from the facts and the clock, it must **not** be a stored property.
A reflection test enforces this against `Quest` (see Tests).

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

### 3. Quest-level derivation — `QuestSnapshot` extension

Pure, no storage. Every function takes an explicit `now` (or `at:`); none read the wall clock internally, so tests stay deterministic.

```swift
extension QuestSnapshot {
    /// A quest is *resolved* once completed (regardless of when).
    var isCompleted: Bool { completedAt != nil }

    /// Failed = its deadline passed without on-time completion.
    /// Completing after the deadline still counts as a miss (the hero already took the hit at the deadline).
    func isFailed(at now: Date) -> Bool {
        if let completedAt { return completedAt > deadline }
        return deadline < now
    }

    /// Still open and its deadline has passed — the set that currently weighs on the hero.
    func isOverdue(at now: Date) -> Bool { !isCompleted && deadline <= now }

    /// 0 … 1, rising as the deadline nears; 0 while further out than the horizon, 1 at/after the deadline.
    /// Undefined-as-0 once completed (a resolved quest exerts no urgency).
    func urgency(at now: Date) -> Double {
        guard !isCompleted else { return 0 }
        let remaining = deadline.timeIntervalSince(now)
        if remaining <= 0 { return 1 }
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
The entry point keeps BLUEPRINT's signature `heroState(quests:now:lastOpened:)` and is deterministic in all three inputs.

Two separate concerns are pinned into the type up front, because getting them wrong later forces a rewrite:

- **`condition` — the visual state, decoupled from the HP scalar.**
  BLUEPRINT's hook is "miss a deadline → 죽은 눈으로 다음날" — a *single* miss flips the look.
  So `condition` is derived from whether *any* unresolved overdue quest exists, independent of how the HP number is tuned.
  A scalar-only `hp` could not express "one miss = dead eyes" without conflating it with the 3-miss death threshold; splitting them means damage-curve tuning never changes the type.
- **`awayFailures` — a historical event feed, explicitly NOT the cause of current hurt.**
  It answers "what did I miss while away" for the "died while you were away" screen and Phase 3 notification reconciliation.
  It uses `isFailed` (so a quest completed *late*, within the window, still shows as a missed event) and may list quests that are since resolved.
  It never feeds `hp`/`condition`, which describe the hero *now*.
  This resolves the late-completion divergence: `awayFailures` is history, `condition`/`hp` are present-tense — they are allowed to tell different stories on purpose.

```swift
/// Present-tense visual state. Derived, never stored.
enum HeroCondition: Sendable { case healthy, wounded, dead }

struct HeroState: Sendable, Equatable {
    let hp: Int
    let maxHP: Int
    let condition: HeroCondition
    /// Quests whose deadline was crossed unmet within (lastOpened, now] — history for the away screen.
    /// Independent of hp/condition; may include since-resolved quests.
    let awayFailures: [UUID]
}

enum HeroDerivation {
    static func state(quests: [QuestSnapshot], now: Date, lastOpened: Date) -> HeroState {
        let maxHP = GameBalance.maxHP
        // Current hurt = currently-unresolved overdue quests. Resolving one heals — recovery is just recomputation.
        let openOverdue = quests.filter { $0.isOverdue(at: now) }.count
        let hp = max(0, maxHP - openOverdue)

        // Any unresolved miss → dead eyes (matches BLUEPRINT). Scalar hp is separate flavor.
        let condition: HeroCondition = openOverdue > 0 ? .dead : .healthy   // .wounded reserved (see Open Questions)

        let awayFailures = quests
            .filter { $0.deadline > lastOpened && $0.deadline <= now && $0.isFailed(at: now) }
            .map(\.id)

        return HeroState(hp: hp, maxHP: maxHP, condition: condition, awayFailures: awayFailures)
    }
}
```

Recovery semantics this encodes (a BLUEPRINT open question): both `hp` and `condition` track **currently-unresolved** overdue quests, so completing or deleting an overdue quest heals and clears the dead eyes.
This is the forgiving default; it falls out naturally from deriving state instead of storing it.
The permanent-scar alternative is captured in Open Questions.

### 5. Tunable balance — `GameBalance`

Every game-balance number lives in one namespace so tuning never touches logic and never risks a stored-state migration (there is none — it is all derived).

```swift
enum GameBalance {
    static let maxHP = 3
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
- `QuestKeeper/Derivation/QuestDerivation.swift` — the `QuestSnapshot` extension (urgency, mobLevel, isFailed, isOverdue).
- `QuestKeeper/Derivation/HeroDerivation.swift` — `HeroState`, `HeroDerivation`.
- `QuestKeeper/Derivation/GameBalance.swift` — constants.
- `QuestKeeper/QuestKeeperApp.swift` — register `Quest` in `Schema` (edit).
- `QuestKeeperTests/DerivationTests.swift` — Swift Testing suite (below).

## Out of Scope (deferred)

- Any UI, `@Query`, `scenePhase`, `TimelineView` — Phase 2.
  `ContentView` and `Item` stay untouched this phase; `Item` removal + hero view come with Phase 2 (this supersedes the earlier note in spec 001 that placed `Item` removal in Phase 1 — it can only go once its `ContentView` consumer is rewritten).
- Notifications — Phase 3.
- Widget / App Group — Phase 4.

## Tests (Swift Testing, `QuestKeeperTests`)

All inputs are hand-built `QuestSnapshot` values with a fixed reference `now`; no `ModelContainer` needed.

1. **Determinism** — `HeroDerivation.state(...)` called twice with identical `(quests, now, lastOpened)` returns `==` results.
2. **Six-months-later reconstruction** — quests with deadlines in the past, `now` six months out, `lastOpened` also in the past: hero `hp` reflects the unresolved overdue count and `condition == .dead` — proving state is rebuilt from facts alone, with zero reliance on intervening events.
3. **Urgency is monotonic in time** — for one un-completed quest, `urgency(at:)` evaluated at increasing `now` is non-decreasing, reaches `1` at/after the deadline, and `0` before the horizon.
4. **Mob level rises with urgency** — same quest, `mobLevel(at:)` non-decreasing as `now` advances toward the deadline; `high` importance never yields a lower tier than `low` at the same `now`.
5. **Completion neutralizes** — a completed quest has `urgency == 0`, `isOverdue == false`; an on-time completion has `isFailed == false`; a late completion (`completedAt > deadline`) has `isFailed == true`.
6. **One miss → dead eyes** — a single open overdue quest yields `condition == .dead`; zero open overdue yields `.healthy`.
7. **Recovery by resolution** — completing/removing the overdue quest at the same `now` raises `hp` and returns `condition` to `.healthy` (derivation over the updated set).
8. **`awayFailures` is history, not current hurt** — a quest completed *late* but within `(lastOpened, now]` appears in `awayFailures` while `condition` is `.healthy` (no open overdue) — the two fields are independent by design.
9. **No derived storage (guardrail)** — enforced by the grep guard in Verification #3, not a `Mirror` test: the `@Model` macro rewrites stored properties into computed accessors over `_$backingData`, so reflecting a `Quest` enumerates backing/observation internals rather than the declared fields. A source-level grep is the reliable enforcer; if a runtime assertion is wanted later, confirm what `Mirror(reflecting:)` actually yields on a `@Model` instance before trusting it.

## Verification

1. `xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'` → succeeds, zero warnings under Swift 6 / strict concurrency `complete`.
2. `xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'` → all nine tests pass.
3. Grep guard: `grep -rnE '(var|let) +(hp|isDead|mobLevel|urgency)' QuestKeeper/Models/` returns nothing (facts only).

## Open Questions (defaults chosen; all tunable without migration)

- **Recovery model** — default: `hp` and `condition` track *currently-unresolved* overdue quests, so resolving one heals and clears the dead eyes.
  Alternative: a failure permanently scars (count historical misses, not just open ones) — makes death sticky, matching the darker framing.
  Decide before Phase 2 wires the hero view, since it changes what "revive" means on screen.
  Note this is now a pure change to `HeroDerivation.state` — the `HeroState` type already carries both `condition` and `hp`, so either model fits without a type change.
- **`.wounded` condition** — reserved but unused in the default derivation (`.healthy`/`.dead` only).
  Candidate meaning: a high-urgency quest is *about* to be missed (deadline imminent, still open) → an intermediate warning look.
  Left out of Phase 1 to keep the first hero view to two sprite states (BLUEPRINT: "건강/사망 2상태 최소 구현").
- **Damage curve** — the `condition` mechanic is binary-on-any-miss (decided, per BLUEPRINT).
  The `hp` scalar's curve is default linear, −1 per open overdue (`maxHP = 3`); this only affects a numeric health bar, not life/death, and is tunable.
- **Mob tier mapping** — default: `importance × urgency` normalized into `0…5`.
  Revisit the tier count once the hero/mob view exists and the numbers can be seen.
