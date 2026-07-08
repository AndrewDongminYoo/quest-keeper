# Daily Dungeon Pivot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the rewritten BLUEPRINT baseline: daily graves, retry tomorrow, retry-aware notification sync, and a first-pass pixel dungeon root surface.

**Architecture:** Keep SwiftData storing only raw facts on `Quest`. Put all time-relative game behavior in pure derivation/action seams, then let SwiftUI consume those derived values. Notification scheduling remains an OS side effect behind the existing `QuestNotificationService.sync` path.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, UserNotifications, Swift Testing, XcodeBuildMCP or `xcodebuild` on iOS Simulator `iPhone 17e`.

## Global Constraints

- Store only raw facts on `Quest`: `id`, `title`, `deadline`, `completedAt`, `importance`.
- Do not store HP, `isDead`, grave count, retry count, monster type, urgency, mob level, notification IDs, or notification scheduled state.
- Daily graves are derived from facts plus `now`; yesterday's missed quests do not appear on the root dungeon.
- "내일 도전하기" mutates the raw `deadline` fact to tomorrow, clears `completedAt`, keeps `importance`, and stores no retry count.
- Completion writes `completedAt`; it does not delete a quest.
- Retry tomorrow uses existing notification `sync`; do not add a separate retry notification API.
- Root UI moves toward `DESIGN.md` with SwiftUI-only MVP styling; no SpriteKit and no new dependency.
- Korean user-facing strings stay Korean.
- Use TDD for behavior changes: add failing Swift Testing coverage before production code.

---

## File Structure

- Modify `QuestKeeper/Derivation/GameBalance.swift`
  - Add daily grave and long quest thresholds.
- Modify `QuestKeeper/Derivation/QuestOutcome.swift`
  - Add `isVisibleDailyGrave(at:calendar:)`.
  - Remove permanent-grave language from deletion semantics.
- Modify `QuestKeeper/Derivation/HeroDerivation.swift`
  - Replace permanent `graves: Int` with `dailyGraves: [UUID]`.
  - Rename the positive tally to `totalVictories`.
- Modify `QuestKeeper/Actions/QuestActions.swift`
  - Add top-level `retryDeadlineTomorrow(from:calendar:)`.
  - Add `QuestActions.retryTomorrow(_:now:calendar:)`.
  - Add pure `QuestActions.needsChunkingGuide(deadline:now:)`.
- Modify `QuestKeeper/ContentView.swift`
  - Partition root rows into pending and visible daily graves.
  - Wire retry tomorrow to `QuestActions.retryTomorrow` and `QuestNotificationService.sync`.
- Modify `QuestKeeper/Views/HeroHeader.swift`
  - Render a compact dungeon HUD with total victories only; no permanent grave count.
- Modify `QuestKeeper/Views/QuestListSections.swift`
  - Render pending floors and daily grave floors.
  - Expose retry action for daily graves.
- Modify `QuestKeeper/Views/QuestRow.swift`
  - Restyle active and daily grave rows using dungeon language.
- Modify `QuestKeeper/Views/QuestEditor.swift`
  - Add a small chunking guide alert before saving oversized quests.
- Modify `QuestKeeperTests/DerivationTests.swift`
  - Replace permanent grave tests with daily grave reset tests.
- Modify `QuestKeeperTests/QuestActionsTests.swift`
  - Add retry tomorrow and chunking guide tests.
  - Change deletion guard expectations away from permanent graves.
- Modify `QuestKeeperTests/QuestNotificationServiceTests.swift`
  - Add retry tomorrow resync coverage using the fake notification center.

---

### Task 1: Daily Grave Derivation

**Files:**
- Modify: `QuestKeeperTests/DerivationTests.swift`
- Modify: `QuestKeeper/Derivation/GameBalance.swift`
- Modify: `QuestKeeper/Derivation/QuestOutcome.swift`
- Modify: `QuestKeeper/Derivation/HeroDerivation.swift`
- Modify: `QuestKeeper/Views/HeroHeader.swift`

**Interfaces:**
- Consumes: `QuestSnapshot.outcome(at:)`, `QuestSnapshot.mobLevel(at:)`
- Produces:
  - `QuestSnapshot.isVisibleDailyGrave(at:calendar:) -> Bool`
  - `HeroState(totalVictories: Int, dailyGraves: [UUID], deathsWhileAway: [UUID])`
  - `GameBalance.dailyGraveVisibilityWindow`
  - `GameBalance.longQuestWarningHorizon`

- [x] **Step 1: Write failing derivation tests**

Replace the permanent grave assertions in `QuestKeeperTests/DerivationTests.swift` with tests like:

```swift
@Test("daily grave visibility resets by local day")
func dailyGraveVisibilityResetsByLocalDay() {
    let calendar = Calendar(identifier: .gregorian)
    let todayGrave = snapshot(deadlineOffset: -60)
    let yesterdayGrave = snapshot(deadlineOffset: -day)

    #expect(todayGrave.outcome(at: now) == .grave)
    #expect(todayGrave.isVisibleDailyGrave(at: now, calendar: calendar))
    #expect(yesterdayGrave.outcome(at: now) == .grave)
    #expect(yesterdayGrave.isVisibleDailyGrave(at: now, calendar: calendar) == false)
}

@Test("hero state exposes total victories and only today's visible graves")
func heroStateHasDailyGravesOnly() {
    let todayGraveID = UUID()
    let oldGraveID = UUID()
    let victoryID = UUID()
    let quests = [
        snapshot(id: todayGraveID, deadlineOffset: -60),
        snapshot(id: oldGraveID, deadlineOffset: -day),
        snapshot(id: victoryID, deadlineOffset: day, completedOffset: -60),
    ]

    let state = HeroDerivation.state(
        quests: quests,
        now: now,
        lastOpened: now.addingTimeInterval(-2 * day)
    )

    #expect(state.totalVictories == 1)
    #expect(state.dailyGraves == [todayGraveID])
    #expect(state.deathsWhileAway == [todayGraveID, oldGraveID])
}
```

- [x] **Step 2: Run tests to verify RED**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/DerivationTests
```

Expected: FAIL because `isVisibleDailyGrave`, `totalVictories`, and `dailyGraves` do not exist, and old `graves` assertions no longer compile.

- [x] **Step 3: Implement daily derivation**

In `QuestKeeper/Derivation/GameBalance.swift`, add:

```swift
/// How long a missed quest may remain emotionally visible in the daily dungeon.
static let dailyGraveVisibilityWindow: TimeInterval = 24 * 60 * 60

/// Deadline distance that triggers the elder chunking guide.
static let longQuestWarningHorizon: TimeInterval = 7 * 24 * 60 * 60
```

In `QuestKeeper/Derivation/QuestOutcome.swift`, add:

```swift
func isVisibleDailyGrave(at now: Date, calendar: Calendar = .current) -> Bool {
    guard outcome(at: now) == .grave else { return false }
    return calendar.isDate(deadline, inSameDayAs: now)
}
```

In `QuestKeeper/Derivation/HeroDerivation.swift`, replace `HeroState` with:

```swift
nonisolated struct HeroState: Sendable, Equatable {
    let totalVictories: Int
    let dailyGraves: [UUID]
    let deathsWhileAway: [UUID]
}
```

Update `HeroDerivation.state` to count victories and collect only visible daily graves:

```swift
static func state(quests: [QuestSnapshot], now: Date, lastOpened: Date) -> HeroState {
    var totalVictories = 0
    var dailyGraves: [UUID] = []

    for quest in quests {
        switch quest.outcome(at: now) {
        case .victory:
            totalVictories += 1
        case .grave:
            if quest.isVisibleDailyGrave(at: now) {
                dailyGraves.append(quest.id)
            }
        case .pending:
            break
        }
    }

    let deathsWhileAway = quests
        .filter { $0.deadline > lastOpened && $0.deadline <= now && $0.outcome(at: now) == .grave }
        .map(\.id)

    return HeroState(
        totalVictories: totalVictories,
        dailyGraves: dailyGraves,
        deathsWhileAway: deathsWhileAway
    )
}
```

- [x] **Step 4: Update HUD compile references**

In `QuestKeeper/Views/HeroHeader.swift`, remove the permanent grave tally and render:

```swift
HStack(spacing: 12) {
    Text("HERO: Leo")
    Text("|")
        .foregroundStyle(.secondary)
    Label("\(state.totalVictories)", systemImage: "trophy.fill")
        .foregroundStyle(.yellow)
        .accessibilityLabel("승리 \(state.totalVictories)")
}
.font(.caption.bold().monospacedDigit())
```

Update the preview initializer:

```swift
HeroHeader(state: HeroState(totalVictories: 3, dailyGraves: [], deathsWhileAway: []), isMourning: false)
```

- [x] **Step 5: Run tests to verify GREEN**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/DerivationTests
```

Expected: PASS.

---

### Task 2: Retry Tomorrow and Chunking Action Seams

**Files:**
- Modify: `QuestKeeperTests/QuestActionsTests.swift`
- Modify: `QuestKeeper/Actions/QuestActions.swift`
- Modify: `QuestKeeper/Derivation/QuestOutcome.swift`

**Interfaces:**
- Consumes: `Quest`, `QuestSnapshot`, `GameBalance.longQuestWarningHorizon`
- Produces:
  - `retryDeadlineTomorrow(from:calendar:) -> Date`
  - `QuestActions.retryTomorrow(_:now:calendar:)`
  - `QuestActions.needsChunkingGuide(deadline:now:) -> Bool`
  - `QuestActions.canDelete(_:at:) -> Bool` no longer encodes a permanent grave rule

- [x] **Step 1: Write failing action tests**

In `QuestKeeperTests/QuestActionsTests.swift`, replace the permanent grave delete test and add retry/chunking tests:

```swift
@Test("delete is raw cleanup, not a permanent grave rule")
func canDeleteIsNotPermanentGraveRule() {
    let grave = QuestSnapshot(id: UUID(), deadline: now.addingTimeInterval(-day), completedAt: nil, importance: .medium)
    let pending = QuestSnapshot(id: UUID(), deadline: now.addingTimeInterval(day), completedAt: nil, importance: .medium)
    let victory = QuestSnapshot(id: UUID(), deadline: now.addingTimeInterval(day), completedAt: now.addingTimeInterval(-day), importance: .medium)

    #expect(QuestActions.canDelete(grave, at: now))
    #expect(QuestActions.canDelete(pending, at: now))
    #expect(QuestActions.canDelete(victory, at: now))
}

@Test("retry tomorrow moves deadline future, clears completion, and keeps importance")
func retryTomorrowMutatesRawFactsOnly() throws {
    let context = try makeContext()
    let quest = Quest(
        title: "리팩터",
        deadline: now.addingTimeInterval(-day),
        importance: .high,
        completedAt: now.addingTimeInterval(-60)
    )
    context.insert(quest)

    QuestActions.retryTomorrow(quest, now: now, calendar: Calendar(identifier: .gregorian))

    #expect(quest.deadline > now)
    #expect(quest.completedAt == nil)
    #expect(quest.importance == .high)
    #expect(quest.snapshot.outcome(at: now) == .pending)
}

@Test("chunking guide triggers only for oversized deadlines")
func chunkingGuideTrigger() {
    let far = now.addingTimeInterval(GameBalance.longQuestWarningHorizon + 60)
    let near = now.addingTimeInterval(GameBalance.longQuestWarningHorizon - 60)

    #expect(QuestActions.needsChunkingGuide(deadline: far, now: now))
    #expect(QuestActions.needsChunkingGuide(deadline: near, now: now) == false)
}
```

- [x] **Step 2: Run tests to verify RED**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/QuestActionsTests
```

Expected: FAIL because retry/chunking APIs do not exist and the old can-delete behavior returns false for graves.

- [x] **Step 3: Implement action seams**

In `QuestKeeper/Actions/QuestActions.swift`, add the pure helper before `enum QuestActions`:

```swift
nonisolated func retryDeadlineTomorrow(from now: Date, calendar: Calendar = .current) -> Date {
    calendar.date(byAdding: .day, value: 1, to: now)
        ?? now.addingTimeInterval(24 * 60 * 60)
}
```

Update `QuestActions`:

```swift
nonisolated static func canDelete(_ snapshot: QuestSnapshot, at now: Date) -> Bool {
    true
}

static func retryTomorrow(_ quest: Quest, now: Date, calendar: Calendar = .current) {
    quest.deadline = retryDeadlineTomorrow(from: now, calendar: calendar)
    quest.completedAt = nil
}

nonisolated static func needsChunkingGuide(deadline: Date, now: Date) -> Bool {
    deadline.timeIntervalSince(now) > GameBalance.longQuestWarningHorizon
}
```

Remove or rewrite comments that say graves are permanent or undeletable.

- [x] **Step 4: Run tests to verify GREEN**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/QuestActionsTests
```

Expected: PASS.

---

### Task 3: Retry Notification Lifecycle Wiring

**Files:**
- Modify: `QuestKeeperTests/QuestNotificationServiceTests.swift`
- Modify: `QuestKeeper/ContentView.swift`
- Modify: `QuestKeeper/Views/QuestListSections.swift`
- Modify: `QuestKeeper/Views/QuestRow.swift`

**Interfaces:**
- Consumes: `QuestActions.retryTomorrow(_:now:calendar:)`
- Consumes: `QuestNotificationService.sync(quest:now:)`
- Produces: retry UI action that clears old notification IDs and schedules new future notifications through the existing sync path.

- [x] **Step 1: Write retry resync test**

In `QuestKeeperTests/QuestNotificationServiceTests.swift`, add:

```swift
@Test("retry tomorrow resync removes old notifications and schedules future requests")
func retryTomorrowResync() async {
    let center = FakeQuestNotificationCenter()
    let service = makeService(center: center)
    let questID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
    let quest = quest(id: questID, deadlineOffset: -hour)

    QuestActions.retryTomorrow(quest, now: now, calendar: Calendar(identifier: .gregorian))
    await service.sync(quest: quest, now: now)

    let identifiers = QuestNotificationPlanner.identifiers(for: questID)
    #expect(center.removedPendingIdentifiers == [identifiers])
    #expect(center.removedDeliveredIdentifiers == [identifiers])
    #expect(center.addedRequests.map(\.identifier) == identifiers)
}
```

- [x] **Step 2: Run tests to verify RED**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/QuestNotificationServiceTests/retryTomorrowResync
```

Expected: FAIL before Task 2 is complete because `QuestActions.retryTomorrow` does not exist. If Task 2 is already complete, this test should PASS without service changes; that confirms the existing sync path satisfies the revised notification spec.

- [x] **Step 3: Wire retry action in the root flow**

In `ContentView`, derive only visible daily graves:

```swift
let dailyGraves = quests.filter { $0.snapshot.isVisibleDailyGrave(at: now) }
```

Pass retry into `QuestListSections`:

```swift
QuestListSections(
    pending: pending,
    dailyGraves: dailyGraves,
    now: now,
    onComplete: complete,
    onRetryTomorrow: retryTomorrow,
    onDelete: delete,
    onEdit: { route = .edit($0) }
)
```

Add:

```swift
private func retryTomorrow(_ quest: Quest) {
    QuestActions.retryTomorrow(quest, now: .now)
    Task { @MainActor in
        let authorization = await notificationService.sync(quest: quest, now: .now)
        notificationAuthorization = authorization
    }
}
```

In `QuestListSections`, replace `graves` with `dailyGraves` and add `onRetryTomorrow: (Quest) -> Void`.

Attach a retry button to each daily grave row:

```swift
DailyGraveRow(quest: quest, onRetryTomorrow: { onRetryTomorrow(quest) })
```

- [x] **Step 4: Run retry notification tests**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/QuestNotificationServiceTests
```

Expected: PASS.

---

### Task 4: First-Pass Dungeon Root UI

**Files:**
- Modify: `QuestKeeper/ContentView.swift`
- Modify: `QuestKeeper/Views/HeroHeader.swift`
- Modify: `QuestKeeper/Views/QuestListSections.swift`
- Modify: `QuestKeeper/Views/QuestRow.swift`

**Interfaces:**
- Consumes: `HeroState.totalVictories`, `QuestSnapshot.mobLevel(at:)`, `QuestSnapshot.isVisibleDailyGrave(at:)`
- Produces: a SwiftUI-only dungeon shell using existing navigation/editor flows.

- [x] **Step 1: Update row types**

In `QuestKeeper/Views/QuestRow.swift`, keep `QuestRow` and replace `GraveRow` with `DailyGraveRow`:

```swift
struct DailyGraveRow: View {
    let quest: Quest
    let onRetryTomorrow: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "xmark.seal.fill")
                .foregroundStyle(.gray)
            VStack(alignment: .leading, spacing: 4) {
                Text(quest.title)
                    .strikethrough()
                Text("오늘의 무덤")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onRetryTomorrow) {
                Label("내일 도전하기", systemImage: "arrow.uturn.forward")
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 6)
    }
}
```

Restyle `QuestRow` to show a dungeon floor, countdown, level badge, and monster symbol without changing its public initializer.

- [x] **Step 2: Update sections**

In `QuestListSections`, use labels:

```swift
Section("던전") { ... }
Section("오늘의 무덤") { ... }
```

Keep swipe complete for pending rows. Do not attach delete to daily grave rows.

- [x] **Step 3: Update root list chrome**

In `ContentView`, apply a first-pass dungeon background:

```swift
.scrollContentBackground(.hidden)
.background(Color(red: 0.11, green: 0.09, blue: 0.15))
```

Use toolbar add label:

```swift
Label("전투 추가", systemImage: "plus")
```

Keep `QuestEditor` as the create/edit surface.

- [x] **Step 4: Build to verify UI compiles**

Run:

```bash
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'
```

Expected: BUILD SUCCEEDED with no new warnings.

---

### Task 5: Chunking Guide Alert

**Files:**
- Modify: `QuestKeeper/Views/QuestEditor.swift`
- Covered by: `QuestKeeperTests/QuestActionsTests.swift` from Task 2

**Interfaces:**
- Consumes: `QuestActions.needsChunkingGuide(deadline:now:)`
- Produces: oversized quest save warning with fixed local copy.

- [x] **Step 1: Add editor state**

In `QuestEditor`, add:

```swift
@State private var showingChunkingGuide = false
@State private var acceptedOversizedQuest = false
```

- [x] **Step 2: Split save trigger from save execution**

Change the save button to call `attemptSave()`:

```swift
Button("저장") { attemptSave() }
```

Add:

```swift
private func attemptSave() {
    if !acceptedOversizedQuest && QuestActions.needsChunkingGuide(deadline: deadline, now: .now) {
        showingChunkingGuide = true
        return
    }
    save()
}
```

- [x] **Step 3: Add alert**

Attach to the `NavigationStack` or `Form`:

```swift
.alert("너무 큰 퀘스트예요", isPresented: $showingChunkingGuide) {
    Button("작게 쪼개기", role: .cancel) { }
    Button("그래도 진행") {
        acceptedOversizedQuest = true
        save()
    }
} message: {
    Text("작게 쪼개면 몹도 작아져요.")
}
```

- [x] **Step 4: Run action tests and build**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/QuestActionsTests
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'
```

Expected: PASS and BUILD SUCCEEDED.

---

### Task 6: Full Verification

**Files:**
- All modified production and test files

**Interfaces:**
- Verifies the complete daily dungeon baseline.

- [x] **Step 1: Run full unit tests**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests
```

Expected: all tests pass.

- [x] **Step 2: Run build**

Run:

```bash
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'
```

Expected: build succeeds with no new warnings.

- [x] **Step 3: Run source guards**

Run:

```bash
! rg -n '(var|let) +(hp|isDead|mobLevel|urgency|victories|graves|outcome|retry|monster)' QuestKeeper/Models/
! rg -n '(notificationID|isNotificationScheduled|reminderEnabled|lastNotificationFiredAt|retryCount)' QuestKeeper/Models/
git diff --check
```

Expected: no matches and no diff hygiene errors.

- [ ] **Step 4: Manual simulator smoke**

Manual flow:

```plaintext
1. Create a short quest.
2. Confirm it appears as a dungeon floor with level and countdown.
3. Complete it and confirm the HUD victory count increases.
4. Create or edit a far-future quest and confirm the elder guide appears.
5. Create a near-deadline quest, advance/reopen after deadline, and confirm today's grave row appears.
6. Tap "내일 도전하기" and confirm it returns to the active dungeon.
```

Expected: root screen no longer shows a permanent grave count or permanent graveyard section.
