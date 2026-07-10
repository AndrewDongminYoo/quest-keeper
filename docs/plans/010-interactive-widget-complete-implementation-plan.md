# Interactive Widget (Complete Action) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete a pending quest with one tap on the Home Screen widget, committed immediately in the widget process, and reflected by the app on the next foreground (warm or cold).

**Architecture:** The widget's `CompleteQuestIntent` opens the shared App Group SwiftData store via an `@ModelActor`, writes `completedAt`, cancels the quest's pending notifications with the app's own identifier scheme, rewrites the App Group snapshot, and reloads the timeline. The app switches to the same explicit-`groupContainer` store and forces a refresh on scenePhase `.active` so a warm foreground sees widget writes before `reconstructOnActivation` runs.

**Tech Stack:** Swift 6 (strict concurrency `complete`), SwiftUI, SwiftData (`@Model`, `@ModelActor`, App Group `groupContainer`), WidgetKit interactive widgets (`AppIntent`, `Button(intent:)`), UserNotifications, Swift Testing. Simulator `iPhone 17e`.

See `docs/specs/009-interactive-widget-complete.md` for the contract.

## Global Constraints

- Persist raw facts only; never store derived state on `Quest` (`hp`, `isDead`, `mobLevel`, `urgency`, victory/grave tallies, `outcome`, notification/widget IDs).
- The intent writes only `completedAt`.
- App Group id: `group.kr.donminzzi.QuestKeeper` (reuse `WidgetDungeonSnapshotStore.appGroupIdentifier`).
- Korean user-facing strings stay intentional (`완료`).
- No third-party dependencies.
- Must compile clean under Swift 6 strict concurrency (no new warnings).
- Unit tests use Swift Testing (`import Testing`, `@Test`, `#expect`); match the target.
- Gate each task: `xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests` and, for target/membership/config changes, also `xcodebuild build -scheme QuestKeeper …` and `xcodebuild build -scheme QuestKeeperWidget …`.

---

## File Structure

- Move `QuestKeeper/Models/Quest.swift` (`Quest` + `Importance`) → `QuestKeeperShared/Quest.swift`. Widget + app link it.
- Keep `QuestKeeper/Models/QuestSnapshot.swift` in the app target (the `extension Quest { var snapshot }` extends the shared type; the widget does not need it).
- Move `QuestKeeper/Notifications/QuestNotificationKind.swift` → `QuestKeeperShared/QuestNotificationKind.swift`.
- Move `QuestKeeper/WidgetSupport/WidgetDungeonPayload+Quest.swift` → `QuestKeeperShared/WidgetDungeonPayload+Quest.swift` (make its mapping usable off the main actor — see Task 5).
- Create `QuestKeeperShared/QuestModelContainer.swift` — the shared container factory.
- Create `QuestKeeperShared/QuestStoreActor.swift` — `@ModelActor` with the pure completion mutation.
- Create `QuestKeeperWidget/CompleteQuestIntent.swift` — the `AppIntent`.
- Modify `QuestKeeper/QuestKeeperApp.swift` — use the shared factory.
- Modify `QuestKeeper/ContentView.swift` — force refresh on `.active`.
- Modify `QuestKeeperWidget/WidgetDungeonView.swift` — add `Button(intent:)`.
- Tests in `QuestKeeperTests/` (Swift Testing).

Each move updates Xcode **target membership** in `QuestKeeper.xcodeproj/project.pbxproj`: remove the file from the app target's `Sources` build phase, add it to the `QuestKeeperShared` target's `Sources`. After each move, build both schemes.

---

### Task 1: Cross-process visibility spike (derisk — decides Task 8)

**Goal:** Empirically determine whether a warm-foregrounded app sees an external store write, and what refresh mechanism is required. No production code ships from this task; it produces a decision recorded in the plan.

**Files:** none committed (throwaway shell steps + a note appended to this plan under "Spike Result").

- [ ] **Step 1: Build, install, launch the app on `iPhone 17e`, create one near-future quest, keep it pending.**

```bash
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -derivedDataPath ./build -quiet
xcrun simctl install 7ED9020C-A21E-425F-AF74-C71C40DA0A13 ./build/Build/Products/Debug-iphonesimulator/QuestKeeper.app
xcrun simctl launch 7ED9020C-A21E-425F-AF74-C71C40DA0A13 kr.donminzzi.QuestKeeper
```

- [ ] **Step 2: Background the app (do NOT terminate), then externally write `completedAt` to the pending quest in the shared store.**

```bash
# background via home; then locate the store and set completedAt = now (TIRD)
STORE=$(find "$HOME/Library/Developer/CoreSimulator/Devices/7ED9020C-A21E-425F-AF74-C71C40DA0A13/data/Containers" -name default.store)
NOW_TIRD=$(echo "$(date +%s) - 978307200" | bc)
sqlite3 "$STORE" "UPDATE ZQUEST SET ZCOMPLETEDAT=$NOW_TIRD WHERE ZCOMPLETEDAT IS NULL LIMIT 1;"
```

- [ ] **Step 3: Foreground the app (warm) and screenshot. Observe whether the quest shows completed.**

Foreground via `xcrun simctl launch` again (no terminate) and capture with `xcrun simctl io … screenshot`.
Expected outcomes:
- If it already reflects warm → SwiftData default cross-process merge works; Task 8 only needs to ensure `reconstructOnActivation` reads a fresh fetch.
- If it stays pending warm but updates on relaunch → Task 8 must force a refresh (rollback/refetch) on `.active`.

- [ ] **Step 4: Record the decision.** Append a "## Spike Result" section to this plan stating the observed behavior and the chosen Task 8 mechanism. Commit the plan update.

```bash
git add docs/plans/010-interactive-widget-complete-implementation-plan.md
git commit -m "docs(plan): record cross-process visibility spike result"
```

---

### Task 2: Move `Quest` + `Importance` to `QuestKeeperShared`

**Files:**
- Move: `QuestKeeper/Models/Quest.swift` → `QuestKeeperShared/Quest.swift`
- Modify: `QuestKeeper.xcodeproj/project.pbxproj` (target membership)

**Interfaces:**
- Produces: `Quest` (`@Model`), `Importance` — now in the shared module, linked by app + widget.

- [ ] **Step 1: Move the file and re-target it.** `git mv QuestKeeper/Models/Quest.swift QuestKeeperShared/Quest.swift`. In Xcode, remove it from the `QuestKeeper` target's Compile Sources and add it to the `QuestKeeperShared` target (which the widget already links). The file contents are unchanged (it already imports only `Foundation` + `SwiftData`).

- [ ] **Step 2: Build both schemes to verify the model resolves in the app and widget.**

Run:
```bash
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -quiet
xcodebuild build -scheme QuestKeeperWidget -destination 'platform=iOS Simulator,name=iPhone 17e' -quiet
```
Expected: both succeed. `QuestSnapshot.swift` still compiles in the app (its `extension Quest` sees the shared type).

- [ ] **Step 3: Run the unit suite (no behavior change expected).**

Run: `xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests -quiet`
Expected: PASS.

- [ ] **Step 4: Commit.**

```bash
git add -A
git commit -m "refactor(model): share Quest and Importance via QuestKeeperShared"
```

---

### Task 3: Shared container factory + explicit App Group store

**Files:**
- Create: `QuestKeeperShared/QuestModelContainer.swift`
- Modify: `QuestKeeper/QuestKeeperApp.swift`

**Interfaces:**
- Produces: `enum QuestModelContainer { static func make() throws -> ModelContainer }` — a `ModelContainer` over `[Quest.self]` in the App Group. Callable off the main actor (the widget intent uses it). Cross-process change visibility is framework-managed SwiftData behavior validated empirically by the Task 1 spike and guaranteed by the Task 8 `.active` refresh — this factory does not toggle history tracking manually.

- [ ] **Step 1: Create the factory.**

```swift
import Foundation
import SwiftData

/// The single source of the on-disk store location. App and widget both open THIS container so a
/// write in one process is visible (via history tracking) to the other. Raw facts only — schema is `[Quest]`.
enum QuestModelContainer {
    static func make() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: Schema([Quest.self]),
            groupContainer: .identifier(WidgetDungeonSnapshotStore.appGroupIdentifier)
        )
        return try ModelContainer(for: Schema([Quest.self]), configurations: [configuration])
    }
}
```

- [ ] **Step 2: Switch the app to the factory.** In `QuestKeeper/QuestKeeperApp.swift`, replace the `sharedModelContainer` closure body with `try QuestModelContainer.make()` (keep the `fatalError` fallback).

```swift
var sharedModelContainer: ModelContainer = {
    do {
        return try QuestModelContainer.make()
    } catch {
        fatalError("Could not create ModelContainer: \(error)")
    }
}()
```

- [ ] **Step 3: Verify the store URL vs. the spike's path (no unintended reset).** Build+run once, then confirm the store still resolves to the same App Group path found in Task 1.

Run:
```bash
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -quiet
find "$HOME/Library/Developer/CoreSimulator/Devices/7ED9020C-A21E-425F-AF74-C71C40DA0A13/data/Containers" -name default.store
```
Expected: same App Group container path as Task 1 (explicit `groupContainer` matches the prior implicit location). If the path differs, note the one-time dev reset in the commit body.

- [ ] **Step 4: Run the unit suite.**

Run: `xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests -quiet`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add -A
git commit -m "feat(store): open the SwiftData store via explicit App Group container"
```

---

### Task 4: Share `QuestNotificationKind` (widget cancels the app's identifiers)

**Files:**
- Move: `QuestKeeper/Notifications/QuestNotificationKind.swift` → `QuestKeeperShared/QuestNotificationKind.swift`
- Modify: `QuestKeeper.xcodeproj/project.pbxproj` (target membership)
- Test: `QuestKeeperTests/WidgetNotificationCancellationTests.swift`

**Interfaces:**
- Consumes: `QuestNotificationKind.identifier(for: UUID) -> String`, `QuestNotificationKind.allCases`.
- Produces: the shared cancellation identifiers `QuestNotificationKind.allCases.map { $0.identifier(for: id) }`.

- [ ] **Step 1: Write the parity test.** The widget must cancel exactly what the app's planner schedules.

```swift
import Foundation
import Testing
@testable import QuestKeeper

struct WidgetNotificationCancellationTests {
    @Test("widget cancels exactly the identifiers the planner schedules")
    func cancellationIdentifiersMatchPlanner() {
        let id = UUID()
        let scheduled = Set(QuestNotificationPlanner.identifiers(for: id))
        let widgetCancels = Set(QuestNotificationKind.allCases.map { $0.identifier(for: id) })
        #expect(widgetCancels == scheduled)
    }
}
```

- [ ] **Step 2: Run it to confirm it passes at the current location (guards the contract before moving).**

Run: `xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/WidgetNotificationCancellationTests -quiet`
Expected: PASS.

- [ ] **Step 3: Move the file to the shared target.** `git mv QuestKeeper/Notifications/QuestNotificationKind.swift QuestKeeperShared/QuestNotificationKind.swift`; remove from `QuestKeeper` target, add to `QuestKeeperShared`. Contents unchanged (imports only `Foundation`).

- [ ] **Step 4: Build both schemes and re-run the parity test.**

Run:
```bash
xcodebuild build -scheme QuestKeeperWidget -destination 'platform=iOS Simulator,name=iPhone 17e' -quiet
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests -quiet
```
Expected: both PASS (`QuestNotificationPlanner` in the app still sees `QuestNotificationKind` via the shared import).

- [ ] **Step 5: Commit.**

```bash
git add -A
git commit -m "refactor(notifications): share QuestNotificationKind for widget cancellation"
```

---

### Task 5: Share the payload mapping off the main actor

**Files:**
- Move: `QuestKeeper/WidgetSupport/WidgetDungeonPayload+Quest.swift` → `QuestKeeperShared/WidgetDungeonPayload+Quest.swift`
- Modify: `QuestKeeper.xcodeproj/project.pbxproj` (target membership)

**Interfaces:**
- Produces: `WidgetDungeonPayload.make(from:including:excluding:generatedAt:)` reachable from the widget, callable within an actor over `[Quest]`.

- [ ] **Step 1: Move the file to `QuestKeeperShared` and adjust isolation.** Drop the `@MainActor` on `make(...)` and make it callable from any actor context — the caller (the app `@MainActor` writer and the widget `@ModelActor`) each passes quests bound to its own context, so the mapping only reads properties within that isolation. Keep the signature identical otherwise.

```swift
import Foundation

extension WidgetDungeonPayload {
    static func make(
        from quests: [Quest],
        including changedQuest: Quest? = nil,
        excluding excludedQuestID: UUID? = nil,
        generatedAt: Date = .now
    ) -> WidgetDungeonPayload {
        // body unchanged from the app version
    }
}
```

- [ ] **Step 2: Build both schemes; fix any actor-isolation diagnostics at the two call sites** (`ContentView` writer stays on `@MainActor`; the widget calls it inside its `@ModelActor` — Task 7).

Run:
```bash
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -quiet
xcodebuild build -scheme QuestKeeperWidget -destination 'platform=iOS Simulator,name=iPhone 17e' -quiet
```
Expected: both succeed.

- [ ] **Step 3: Run the unit suite** (existing `WidgetDungeonPayloadTests` cover `make`).

Run: `xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests -quiet`
Expected: PASS.

- [ ] **Step 4: Commit.**

```bash
git add -A
git commit -m "refactor(widget): share payload mapping for cross-process snapshot writes"
```

---

### Task 6: Completion core on a `@ModelActor`

**Files:**
- Create: `QuestKeeperShared/QuestStoreActor.swift`
- Test: `QuestKeeperTests/QuestStoreActorTests.swift`

**Interfaces:**
- Produces: `@ModelActor actor QuestStoreActor { func complete(id: UUID, now: Date) throws -> Bool }` — returns `true` if it wrote the fact, `false` if no-op (already completed / missing). Raw fact only.

- [ ] **Step 1: Write the failing test** (in-memory container; single-process correctness of the mutation).

```swift
import Foundation
import SwiftData
import Testing
@testable import QuestKeeper

@MainActor
struct QuestStoreActorTests {
    private func container() throws -> ModelContainer {
        try ModelContainer(for: Quest.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    @Test("complete writes completedAt for a pending quest")
    func completesPending() async throws {
        let c = try container()
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let quest = Quest(title: "물 마시기", deadline: now.addingTimeInterval(3600), importance: .medium)
        c.mainContext.insert(quest)
        try c.mainContext.save()
        let id = quest.id

        let wrote = try await QuestStoreActor(modelContainer: c).complete(id: id, now: now)

        #expect(wrote == true)
        let fetched = try c.mainContext.fetch(FetchDescriptor<Quest>(predicate: #Predicate { $0.id == id })).first
        #expect(fetched?.completedAt == now)
    }

    @Test("complete is idempotent on an already-completed quest")
    func idempotent() async throws {
        let c = try container()
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let quest = Quest(title: "x", deadline: now, importance: .low, completedAt: now.addingTimeInterval(-10))
        c.mainContext.insert(quest); try c.mainContext.save()

        let wrote = try await QuestStoreActor(modelContainer: c).complete(id: quest.id, now: now)

        #expect(wrote == false)
        let fetched = try c.mainContext.fetch(FetchDescriptor<Quest>()).first
        #expect(fetched?.completedAt == now.addingTimeInterval(-10)) // unchanged
    }

    @Test("complete is a no-op for a missing id")
    func missingIsNoOp() async throws {
        let c = try container()
        let wrote = try await QuestStoreActor(modelContainer: c).complete(id: UUID(), now: .now)
        #expect(wrote == false)
    }
}
```

- [ ] **Step 2: Run to verify RED.** `-only-testing:QuestKeeperTests/QuestStoreActorTests` → FAIL (`QuestStoreActor` undefined).

- [ ] **Step 3: Implement the actor.**

```swift
import Foundation
import SwiftData

@ModelActor
actor QuestStoreActor {
    /// Writes only the raw `completedAt` fact. Returns whether a write occurred.
    func complete(id: UUID, now: Date) throws -> Bool {
        var descriptor = FetchDescriptor<Quest>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let quest = try modelContext.fetch(descriptor).first else { return false }
        guard quest.completedAt == nil else { return false }
        quest.completedAt = now
        try modelContext.save()
        return true
    }

    /// All quests, as the payload source, within the actor's isolation.
    func snapshotPayload(generatedAt: Date) throws -> WidgetDungeonPayload {
        let quests = try modelContext.fetch(FetchDescriptor<Quest>())
        return WidgetDungeonPayload.make(from: quests, generatedAt: generatedAt)
    }
}
```

- [ ] **Step 4: Run to verify GREEN.** `-only-testing:QuestKeeperTests/QuestStoreActorTests` → PASS.

- [ ] **Step 5: Commit.**

```bash
git add -A
git commit -m "feat(store): add QuestStoreActor completion mutation"
```

---

### Task 7: `CompleteQuestIntent`

**Files:**
- Create: `QuestKeeperWidget/CompleteQuestIntent.swift`

**Interfaces:**
- Consumes: `QuestModelContainer.make()`, `QuestStoreActor`, `QuestNotificationKind`, `WidgetDungeonSnapshotStore`.
- Produces: `struct CompleteQuestIntent: AppIntent` with `@Parameter var questID: String`.

- [ ] **Step 1: Implement the intent.**

```swift
import AppIntents
import SwiftData
import UserNotifications
import WidgetKit

struct CompleteQuestIntent: AppIntent {
    static let title: LocalizedStringResource = "퀘스트 완료"

    @Parameter(title: "questID") var questID: String

    init() {}
    init(questID: UUID) { self.questID = questID.uuidString }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: questID) else { return .result() }

        let container = try QuestModelContainer.make()
        let actor = QuestStoreActor(modelContainer: container)

        let wrote = try await actor.complete(id: id, now: .now)
        guard wrote else { return .result() } // idempotent: nothing else to do

        // best-effort notification cancellation — never blocks the committed fact
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: QuestNotificationKind.allCases.map { $0.identifier(for: id) }
        )

        // rewrite the snapshot the TimelineProvider reads — must not be skipped
        let payload = try await actor.snapshotPayload(generatedAt: .now)
        try? WidgetDungeonSnapshotStore().save(payload)

        WidgetCenter.shared.reloadTimelines(ofKind: "QuestKeeperWidget")
        return .result()
    }
}
```

- [ ] **Step 2: Confirm `WidgetDungeonSnapshotStore.save(_:)` signature; adapt if it differs** (read `QuestKeeperShared/WidgetDungeonSnapshotStore.swift`). If `save` is throwing/async, match it.

- [ ] **Step 3: Build the widget scheme.**

Run: `xcodebuild build -scheme QuestKeeperWidget -destination 'platform=iOS Simulator,name=iPhone 17e' -quiet`
Expected: succeeds.

- [ ] **Step 4: Commit.**

```bash
git add -A
git commit -m "feat(widget): add CompleteQuestIntent for one-tap completion"
```

---

### Task 8: App refreshes on `.active` (per spike result)

**Files:**
- Modify: `QuestKeeper/ContentView.swift`

**Interfaces:**
- Consumes: the spike's decision (Task 1). Ensures a warm foreground reflects widget writes before `reconstructOnActivation`.

Spike result (Task 1): warm foreground is **stale** — the rendered `@Query` list does not reflect an external write. So the fix must refresh the `@Query`-bound view itself, not merely feed `reconstructOnActivation` a fresh fetch.

- [ ] **Step 1: Refresh the in-memory context on `.active` so the `@Query` refetches from disk.** The app always saves immediately (no pending unsaved edits), so discarding the cached context state is safe and forces a refault from the store:

```swift
.onChange(of: scenePhase, initial: true) { _, phase in
    if phase == .active {
        modelContext.rollback()   // drop cached state so @Query re-reads widget-committed writes
        onBecameActive(now: .now)
    }
}
```

`reconstructOnActivation` then reads the refreshed `quests`. Keep its body unchanged.

- [ ] **Step 2: Re-run the Task 1 spike harness to VERIFY the warm case now updates.** Rebuild/install, launch (PID_A), background via another app, external `completedAt` write, warm foreground (confirm same PID), screenshot: the completed quest must now leave the pending list and the victory count increment.

Run the same background→write→foreground→screenshot sequence from Task 1.
Expected: warm foreground reflects the write.

- [ ] **Step 3: If `rollback()` is insufficient, escalate — do not ship a warm-stale build.** Enable persistent history tracking on `QuestModelContainer` and observe `.NSPersistentStoreRemoteChange` to trigger the refresh; re-run the harness. Record whichever mechanism worked in the Spike Result section.

- [ ] **Step 4: Build and run the unit suite.**

Run: `xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests -quiet`
Expected: PASS (`reconstructOnActivation` is already covered; this only changes the input source).

- [ ] **Step 5: Commit.**

```bash
git add -A
git commit -m "fix(app): refresh store on activation so warm foreground sees widget writes"
```

---

### Task 9: Widget complete buttons

**Files:**
- Modify: `QuestKeeperWidget/WidgetDungeonView.swift`

**Interfaces:**
- Consumes: `CompleteQuestIntent(questID:)`, the entry's pending mobs (which carry `id`).

- [ ] **Step 1: Add a `Button(intent:)` to each pending mob row (medium) and to the top mob (small).** Read `WidgetDungeonView.swift` first to match its row rendering and `WidgetDungeonEntryState` shape; wrap the complete affordance in:

```swift
Button(intent: CompleteQuestIntent(questID: mob.id)) {
    Image(systemName: "checkmark")
        .font(.caption.weight(.bold))
}
.buttonStyle(.plain)
.tint(Color(red: 0.18, green: 0.54, blue: 0.29))
.accessibilityLabel("완료")
```

Only pending mobs get the button; completed/grave entries do not. Keep row height stable (spec 008 rule).

- [ ] **Step 2: Build the widget scheme.**

Run: `xcodebuild build -scheme QuestKeeperWidget -destination 'platform=iOS Simulator,name=iPhone 17e' -quiet`
Expected: succeeds.

- [ ] **Step 3: Commit.**

```bash
git add -A
git commit -m "feat(widget): render one-tap 완료 buttons on pending mobs"
```

---

### Task 10: Final verification

**Files:** validate only.

- [ ] **Step 1: Full gate.**

Run:
```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests -quiet
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -quiet
xcodebuild build -scheme QuestKeeperWidget -destination 'platform=iOS Simulator,name=iPhone 17e' -quiet
git diff --check
! rg -n '(var|let) +(hp|isDead|mobLevel|urgency|victories|graves|outcome|retry|monster|notificationID|isNotificationScheduled|reminderEnabled|lastNotificationFiredAt|widgetID)' QuestKeeper/Models/ QuestKeeperShared/
```
Expected: all pass; guard returns nothing.

- [ ] **Step 2: Manual cross-process gate (the acceptance point).** Add the widget, create a near-deadline quest, background the app, tap `완료` on the widget, foreground the app: the quest shows completed **warm**, its notification no longer fires, and a second tap is a no-op.

- [ ] **Step 3: Adversarial re-check.** Run an `advisor` pass on the finished diff focused on cross-process write coordination and the notification lifecycle (per the spec's routed correctness check), then capture the resulting rule as a knowledge-wiki page (new precedent).

- [ ] **Step 4: Open the PR** once green.

---

## Spike Result (Task 1)

Ran 2026-07-10 on `iPhone 17e`.

- **Setup:** app foregrounded with one pending quest (`여유를 만끽하세요`, victory count 1). Backgrounded by foregrounding another app (process kept alive — same PID `77539` before and after, so genuinely warm, not a cold relaunch). While backgrounded, an external process set `completedAt = now` on that quest directly in the shared store (stand-in for the widget's cross-process write).
- **Observation:** on **warm** foreground the app did **not** reflect the write — the quest still rendered as active in `던전` and the victory count stayed `1`. The countdown kept ticking (35분 → 34분), confirming the `TimelineView` was live; only the `@Query` data was stale. A cold relaunch reads it correctly.
- **Conclusion:** SwiftData `@Query` does **not** observe external-process writes by default in this configuration. The stale surface is the rendered `@Query`, not just `reconstructOnActivation`'s input — so Task 8 must refresh the context itself (`modelContext.rollback()` on `.active`, escalating to persistent history tracking + `.NSPersistentStoreRemoteChange` if rollback proves insufficient), and Task 8 Step 2 re-runs this harness as the gate. This is new precedent (no prior QuestKeeper rule); capture the working mechanism as a wiki page in Task 10.
