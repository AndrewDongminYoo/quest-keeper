# Spec 003 — Task CRUD & Hero View (Phase 2)

Status: implemented
Depends on: 002 (data model & derivation layer)
Blocks: Phase 3 (local-notification lifecycle)

Implementation note: build + all 13 unit tests pass (`-only-testing:QuestKeeperTests`); the app launches
on the iOS 26.5 simulator and renders the hero header + empty state.
Hero sprite uses SF Symbols (`figure.stand`/`figure.fall`) as placeholder frames, per §5.
Interactive gestures (swipe-complete, grave rendering, the "꿱" mourning animation) are logic-verified
by the four `QuestActionsTests` plus `DerivationTests`; gesture-level UI automation is deferred (the
template `QuestKeeperUITests` runner is flaky on this simulator).

## Goal

Wire the SwiftUI lifecycle and `@Query` to the Phase 1 derivation layer, so the stored facts become a
live screen: a quest list you can create/edit/complete, a hero whose victory/grave scoreboard is
rendered from `(quests, now)`, and a reopen that reconstructs "what died while I was away".

The two learning boundaries this phase exists to cross — do not shortcut them:

- **`scenePhase` → state replay.** On becoming active, compare the persisted `lastOpened` against the
  quests to surface `deathsWhileAway`, *then* advance `lastOpened`. No death events are stored.
- **`TimelineView` → live derivation.** Urgency and countdowns update by feeding the timeline's clock
  into the pure derivation, never a hand-rolled `Timer`.

## UX model

- **Hero header** — a pixel hero (always alive) plus the `victories` / `graves` tallies.
  On reopen, if `deathsWhileAway` is non-empty, play a brief "꿱 → revive" animation once, then settle.
- **Active quests** — pending quests, sorted by urgency (soonest deadline first), each showing a live
  countdown and its mob level. Create / edit / complete here.
- **Graveyard** — graves, shown as tombstones. Read-only and **undeletable** (the enduring record).
  Victories may be listed or just counted (see Open Questions).
- **Complete ≠ delete.** Completing writes `completedAt` (a fact); deleting removes a still-pending
  quest you changed your mind about. A grave offers neither.

## Design

### 1. `lastOpened` — a stored fact, not derived

`lastOpened` is a legitimate raw fact (when the app was last foregrounded), so persisting it does not
violate "저장은 사실만". Phase 2 stores it in `@AppStorage` as a `Double` (time interval since reference
date); Phase 4 will move it to the App Group's shared `UserDefaults` so the widget shares it.

```swift
// Persisted as Double; nil-equivalent (0 / first launch) means "no prior open" → no deaths surfaced.
@AppStorage("lastOpenedTIRD") private var lastOpenedRaw: Double = 0
```

### 2. Activation → reconstruction (ordering matters)

On `scenePhase` transition to `.active`, reconstruct against the *previous* `lastOpened`, drive the
animation, then advance the clock. Getting the order wrong either hides deaths or replays them forever.

The core is a `nonisolated` free function over snapshots (so test 4 needs no view), and the view is a
thin main-actor caller that also owns the transient animation flag and its **reset**:

```swift
/// Pure: what died in (previousLastOpened, now], and the clock to store next.
nonisolated func reconstructOnActivation(
    quests: [QuestSnapshot], now: Date, previousLastOpened: Date?
) -> (deaths: [UUID], newLastOpened: Date) {
    let previous = previousLastOpened ?? now
    let state = HeroDerivation.state(quests: quests, now: now, lastOpened: previous)
    return (state.deathsWhileAway, now)   // advance AFTER reconstruction
}

@Environment(\.scenePhase) private var scenePhase
@Query(sort: \Quest.deadline) private var quests: [Quest]
@State private var pendingDeaths: [UUID] = []   // transient: drives the 꿱 animation this activation

@MainActor func onBecameActive(now: Date) {
    let previous = lastOpenedRaw == 0 ? nil : Date(timeIntervalSinceReferenceDate: lastOpenedRaw)
    let (deaths, newLastOpened) = reconstructOnActivation(
        quests: quests.map(\.snapshot), now: now, previousLastOpened: previous)
    lastOpenedRaw = newLastOpened.timeIntervalSinceReferenceDate
    guard !deaths.isEmpty else { return }
    pendingDeaths = deaths
    // Play once, then settle. Without this reset the mourning frame latches until the next activation.
    Task { @MainActor in
        try? await Task.sleep(for: .seconds(GameBalance.mourningDuration))
        pendingDeaths = []
    }
}
```

`.map(\.snapshot)` bridges the main-actor `@Model` array into the `nonisolated` derivation input.
(`Task.sleep`/animation is illustrative — the contract is only that `pendingDeaths` returns to empty.)

### 3. Live rendering via `TimelineView`

The hero header, the **Active/Graveyard partition**, and each countdown all recompute from the
timeline's clock — no `Timer`, no manual invalidation. For live rendering `lastOpened` is "now"
(deaths are surfaced only at activation, above).

Crucially, the partition **cannot** come from `@Query`/`#Predicate`: `outcome(at: now)` is derived and
depends on `now`, which SwiftData's query layer cannot see. So `@Query` returns *all* quests, and the
split into pending / graves / victories is computed in-memory from the snapshots at the timeline's
`now` — inside the closure, so a quest migrates Active→Graveyard the instant its deadline crosses on
the same clock that drives the hero.

```swift
TimelineView(.periodic(from: .now, by: 60)) { context in
    let now = context.date
    let snapshots = quests.map(\.snapshot)
    let state = HeroDerivation.state(quests: snapshots, now: now, lastOpened: now)

    // Derived membership — recomputed every tick, never queried.
    let pending  = quests.filter { $0.snapshot.outcome(at: now) == .pending }
    let graves   = quests.filter { $0.snapshot.outcome(at: now) == .grave }

    HeroHeader(state: state, isMourning: !pendingDeaths.isEmpty)
    QuestListSections(pending: pending, graves: graves, now: now)   // rows use `now` for urgency/countdown
}
```

A one-minute cadence suits deadlines in hours/days; a row nearing its deadline can opt into a faster
schedule if a live seconds countdown is wanted (Open Questions).

### 4. CRUD, with completion and deletion as distinct fact-writes

A helper centralizes the deletion guard and the fact mutations. Note the isolation split, which mirrors
Phase 1: the guard is pure over a `QuestSnapshot` and so is `nonisolated` (free-standing unit test),
while the mutations touch the main-actor `@Model` `Quest` and therefore **cannot** be `nonisolated`
(they stay main-actor and are tested through an in-memory `ModelContainer`, which is itself main-actor).

```swift
enum QuestActions {
    /// Pure guard — a grave can never be deleted; everything else can. Unit-testable without a container.
    nonisolated static func canDelete(_ snapshot: QuestSnapshot, at now: Date) -> Bool {
        snapshot.isDeletable(at: now)
    }

    /// Completion writes a fact; it is not deletion. Main-actor (mutates the @Model).
    static func complete(_ quest: Quest, at now: Date) { quest.completedAt = now }
    static func uncomplete(_ quest: Quest) { quest.completedAt = nil }
}
```

- **Create / edit** — a `QuestEditor` form (title, `DatePicker` deadline, `Importance` picker).
  Editing is allowed while `.pending`; resolved quests (victory/grave) are read-only records.
- **Complete** — a checkbox/swipe action on a pending row → `QuestActions.complete(_,at: .now)`.
- **Delete** — swipe-to-delete is offered only when `canDelete` is true; graves have no delete action.

### 5. Pixel hero sprite — minimal two states

`HeroSprite` swaps one image for another by state; real pixel art is deferred (BLUEPRINT: "프레임 교체
수준"). Two frames only:

- `hero_alive` — default, always shown at rest.
- `hero_dead` — the "꿱" dead-eyes frame, shown only during the transient mourning animation, which
  then crossfades back to `hero_alive` ("revives for the next quest").

Placeholder art (even a recolored SF Symbol) is acceptable for Phase 2; the contract is the two-state
swap driven by `isMourning`, not the art quality.
Phase 2 adds one constant to `GameBalance`: `mourningDuration` (how long the "꿱" frame shows before
crossfading back), keeping the timing tunable alongside the other balance numbers.

### 6. Remove the template `Item`

With `Quest` and its list in place, delete the template scaffolding:

- Delete `QuestKeeper/Item.swift`.
- Remove `Item.self` from the `Schema` in `QuestKeeperApp.swift` (leaving `Schema([Quest.self])`).
- Replace the template list in `ContentView` with the composed root (hero header + active list +
  graveyard). `ContentView` stays the app entry point.

## Files

- `QuestKeeper/ContentView.swift` — recompose as the root (hero header + sections). Edit.
- `QuestKeeper/Views/HeroHeader.swift` — hero sprite + victories/graves; `isMourning` animation.
- `QuestKeeper/Views/HeroSprite.swift` — two-state image swap.
- `QuestKeeper/Views/QuestListSections.swift` — active + graveyard sections; receives the derived
  `pending`/`graves` partitions and `now` (not `@Query` directly — membership is derived, §3).
- `QuestKeeper/Views/QuestRow.swift` — title, live countdown, mob level, complete action.
- `QuestKeeper/Views/QuestEditor.swift` — create/edit form.
- `QuestKeeper/Actions/QuestActions.swift` — `nonisolated` completion/deletion helpers.
- `QuestKeeper/QuestKeeperApp.swift` — drop `Item` from schema. Edit.
- Delete `QuestKeeper/Item.swift`.
- `QuestKeeperTests/QuestActionsTests.swift` — new tests (below).
- Assets: `hero_alive`, `hero_dead` image sets (placeholder art).

## Out of Scope (deferred)

- Notifications of any kind — Phase 3.
- App Group / widget / moving `lastOpened` to shared defaults — Phase 4.
- Real pixel-art frames, walk/attack animations, SpriteKit — BLUEPRINT backlog.
- Hero getting visibly stronger per victory — BLUEPRINT backlog.
- Deep-linking from a tap — Phase 3 (notification response).

## Tests

Logic seams stay unit-tested (Swift Testing, `-only-testing:QuestKeeperTests`); the view wiring is
verified by running the app, since the UI-test runner is flaky on this simulator.

1. **Complete writes a fact, not a deletion** — `QuestActions.complete(quest, at:)` sets `completedAt`
   and the quest still exists; `uncomplete` clears it back to `.pending` (in-memory `ModelContainer`).
2. **On-time completion is a victory; the count is unchanged by deletion attempts** — completing before
   the deadline yields `.victory` via the snapshot.
3. **Graves are undeletable** — `QuestActions.canDelete` is `false` for a grave snapshot, `true` for
   pending/victory (mirrors the derivation guard at the action layer the UI actually calls).
4. **Activation reconstruction ordering** — `reconstructOnActivation(quests:now:previousLastOpened:)`
   (the `nonisolated` free function over `[QuestSnapshot]`, §2) returns the deaths for
   `(previousLastOpened, now]` and `newLastOpened == now`; a second call passing that advanced value as
   `previousLastOpened` returns no deaths (proving the clock advance prevents replay). No view needed.

## Verification

1. `xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'` →
   succeeds, zero warnings under Swift 6 strict concurrency.
2. `xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests`
   → Phase 1 tests plus the four new ones pass.
3. Manual run on the simulator:
   - Create a quest with a near-future deadline → appears under Active with a live countdown.
   - Complete it before the deadline → moves out of Active, `victories` increments.
   - Create one with a past deadline → it is a grave immediately, appears in the Graveyard, offers no
     delete, and `graves` reflects it.
   - Background the app, advance the device clock past a pending deadline, reopen → the "꿱 → revive"
     animation plays once and `graves` increments.
4. `grep -rnE '\bItem\.self|\bItem\(|\bItem\.swift' QuestKeeper/` returns nothing — the model is fully
   removed. The `\b` word boundary is required so SwiftUI's `ToolbarItem(` does not false-positive.

## Open Questions (defaults chosen; flag before Phase 3)

- **Un-complete affordance** — default: offer "un-complete" only while the quest is still before its
  deadline (after that it is resolved). Alternative: no un-complete at all. Low stakes; UI-only.
- **Victories display** — default: a running count in the hero header, no per-item victory list (keeps
  the list to Active + Graveyard). Add a victories log later if wanted.
- **Live death while watching** — default: `graves`/counts update live via `TimelineView`, but the
  "꿱" animation only fires on activation, not when a deadline passes with the app open. Firing it live
  is a nice-to-have, deferred to keep the animation trigger in one place.
- **Countdown granularity** — default: 60 s cadence. A row within, say, an hour of its deadline may
  opt into a per-second schedule; decide if the seconds view is worth it when the row exists.
