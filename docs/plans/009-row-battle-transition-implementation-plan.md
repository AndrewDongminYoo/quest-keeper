# Row Battle Transition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a short row-level battle transition before completed pending quests leave the home board.

**Architecture:** Keep `ContentView` as the only fact mutation and lifecycle owner.
Add a pure `QuestBattleResolution` policy for timing and duplicate guards, pass a captured `completedAt` timestamp through the completion callback path, and let `SwipeableQuestRow` own only transient SwiftUI animation state.
Render battle feedback in `QuestRow` from an explicit `QuestBattlePhase`.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Swift Testing, UserNotifications, WidgetKit, iOS Simulator `iPhone 17e`.

## Global Constraints

- Use `docs/{notes,plans,specs}` for project docs.
- Keep markdown prose sentence-per-line with no hard wraps.
- Keep Korean user-facing strings intentional.
- Preserve create, edit, complete, retry tomorrow, delete, notification sync, activation replay, and widget snapshot behavior.
- Do not add stored derived fields to `Quest`.
- Do not add third-party dependencies.
- Do not introduce SpriteKit, SceneKit, bitmap asset production, physics, achievement systems, or new gameplay mechanics.
- The row transition delay is `0.82` seconds.
- The defeated phase begins at `0.34` seconds.
- The completion fact must use the swipe start timestamp, not the delayed commit timestamp.
- Validate with `xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests`.
- Validate with `xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'`.

---

## File Structure

- Create `QuestKeeper/Views/QuestBattleResolution.swift`.
  This file contains pure nonisolated battle phase and timing policy.
- Create `QuestKeeperTests/QuestBattleResolutionTests.swift`.
  This file tests the timing policy and duplicate-completion guard without SwiftUI rendering.
- Modify `QuestKeeper/Views/QuestListSections.swift`.
  This file owns `SwipeableQuestRow`, so it will capture completion time, delay commit, and disable row interactions while resolving.
- Modify `QuestKeeper/Views/QuestRow.swift`.
  This file will render `QuestBattlePhase` without changing stored quest facts.
- Modify `QuestKeeper/Views/HomeDungeonBoardView.swift`.
  This file will forward the timestamp-aware completion callback.
- Modify `QuestKeeper/ContentView.swift`.
  This file will accept the captured completion timestamp while preserving notification cancellation and widget snapshot writes.
- Modify `QuestKeeperTests/QuestActionsTests.swift`.
  This file already tests explicit completion timestamps and will gain a deadline-edge contract test.

---

### Task 1: Battle Resolution Policy

**Files:**
- Create: `QuestKeeper/Views/QuestBattleResolution.swift`
- Create: `QuestKeeperTests/QuestBattleResolutionTests.swift`

**Interfaces:**
- Produces: `nonisolated enum QuestBattlePhase: Equatable`
- Produces: `nonisolated enum QuestBattleResolution`
- Produces: `QuestBattleResolution.defeatedPhaseDelay: TimeInterval`
- Produces: `QuestBattleResolution.commitDelay: TimeInterval`
- Produces: `QuestBattleResolution.phase(elapsed: TimeInterval) -> QuestBattlePhase`
- Produces: `QuestBattleResolution.shouldAcceptCompletion(isResolving: Bool) -> Bool`

- [ ] **Step 1: Write failing policy tests**

Create `QuestKeeperTests/QuestBattleResolutionTests.swift`:

```swift
import Foundation
import Testing
@testable import QuestKeeper

struct QuestBattleResolutionTests {
    @Test("battle phases progress from idle to striking to defeated")
    func battlePhasesProgress() {
        #expect(QuestBattleResolution.phase(elapsed: -0.01) == .idle)
        #expect(QuestBattleResolution.phase(elapsed: 0) == .striking)
        #expect(QuestBattleResolution.phase(elapsed: QuestBattleResolution.defeatedPhaseDelay - 0.01) == .striking)
        #expect(QuestBattleResolution.phase(elapsed: QuestBattleResolution.defeatedPhaseDelay) == .defeated)
        #expect(QuestBattleResolution.phase(elapsed: QuestBattleResolution.commitDelay) == .defeated)
    }

    @Test("battle timing stays short and ordered")
    func battleTimingStaysShortAndOrdered() {
        #expect(QuestBattleResolution.defeatedPhaseDelay == 0.34)
        #expect(QuestBattleResolution.commitDelay == 0.82)
        #expect(QuestBattleResolution.defeatedPhaseDelay > 0)
        #expect(QuestBattleResolution.defeatedPhaseDelay < QuestBattleResolution.commitDelay)
        #expect(QuestBattleResolution.commitDelay < 1)
    }

    @Test("resolving rows reject duplicate completion")
    func resolvingRowsRejectDuplicateCompletion() {
        #expect(QuestBattleResolution.shouldAcceptCompletion(isResolving: false))
        #expect(!QuestBattleResolution.shouldAcceptCompletion(isResolving: true))
    }
}
```

- [ ] **Step 2: Run policy tests to verify RED**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/QuestBattleResolutionTests -quiet
```

Expected: FAIL because `QuestBattleResolution` does not exist.

- [ ] **Step 3: Add minimal policy implementation**

Create `QuestKeeper/Views/QuestBattleResolution.swift`:

```swift
import Foundation

nonisolated enum QuestBattlePhase: Equatable {
    case idle
    case striking
    case defeated
}

nonisolated enum QuestBattleResolution {
    static let defeatedPhaseDelay: TimeInterval = 0.34
    static let commitDelay: TimeInterval = 0.82

    static func phase(elapsed: TimeInterval) -> QuestBattlePhase {
        if elapsed < 0 { return .idle }
        if elapsed < defeatedPhaseDelay { return .striking }
        return .defeated
    }

    static func shouldAcceptCompletion(isResolving: Bool) -> Bool {
        !isResolving
    }
}
```

- [ ] **Step 4: Run policy tests to verify GREEN**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/QuestBattleResolutionTests -quiet
```

Expected: PASS.

- [ ] **Step 5: Commit Task 1**

Run:

```bash
git add QuestKeeper/Views/QuestBattleResolution.swift QuestKeeperTests/QuestBattleResolutionTests.swift
git commit -m "test(ui): cover quest battle resolution policy"
```

---

### Task 2: Timestamp-Aware Completion Callback

**Files:**
- Modify: `QuestKeeper/ContentView.swift`
- Modify: `QuestKeeper/Views/HomeDungeonBoardView.swift`
- Modify: `QuestKeeper/Views/QuestListSections.swift`
- Test: `QuestKeeperTests/QuestActionsTests.swift`

**Interfaces:**
- Consumes: `QuestActions.complete(_ quest: Quest, at completedAt: Date)`
- Produces: timestamp-aware callback type `(Quest, Date) -> Void` through the home board.
- Preserves: notification cancellation and widget snapshot writes in `ContentView.complete`.

- [ ] **Step 1: Add deadline-edge completion test**

Append this test to `QuestKeeperTests/QuestActionsTests.swift`:

```swift
    @Test("complete records the action timestamp even near a deadline")
    func completeRecordsActionTimestampNearDeadline() {
        let deadline = Date(timeIntervalSinceReferenceDate: 820_584_000)
        let actionTime = deadline.addingTimeInterval(-0.1)
        let quest = Quest(title: "Finish before the gate closes", deadline: deadline, importance: .medium)

        QuestActions.complete(quest, at: actionTime)

        #expect(quest.completedAt == actionTime)
        #expect(quest.snapshot.outcome(at: deadline.addingTimeInterval(1)) == .victory)
    }
```

- [ ] **Step 2: Run action tests**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/QuestActionsTests -quiet
```

Expected: PASS.
This test documents the timestamp contract before the UI callback is changed.

- [ ] **Step 3: Update callback signatures**

Change the callback type in `QuestKeeper/Views/HomeDungeonBoardView.swift`:

```swift
let onComplete: (Quest, Date) -> Void
```

Change the callback type in `QuestKeeper/Views/QuestListSections.swift`:

```swift
let onComplete: (Quest, Date) -> Void
```

Change `SwipeableQuestRow` to accept the same type:

```swift
let onComplete: (Quest, Date) -> Void
```

- [ ] **Step 4: Update ContentView completion entry point**

In `QuestKeeper/ContentView.swift`, pass the timestamp-aware function:

```swift
onComplete: complete,
```

Replace `complete(_:)` with:

```swift
private func complete(_ quest: Quest, at completedAt: Date = .now) {
    let questID = quest.id
    QuestActions.complete(quest, at: completedAt)
    writeWidgetSnapshot(including: quest)
    Task { @MainActor in
        await notificationService.cancel(questID: questID)
    }
}
```

- [ ] **Step 5: Temporarily call completion immediately from the row**

In `SwipeableQuestRow.actionButton` for `"완료"`, keep behavior compiling by passing the current action time:

```swift
actionButton(title: "완료", systemImage: "checkmark", color: Color(red: 0.18, green: 0.54, blue: 0.29)) {
    reset()
    onComplete(quest, .now)
}
```

- [ ] **Step 6: Run focused compile tests**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/QuestActionsTests -quiet
```

Expected: PASS.

- [ ] **Step 7: Commit Task 2**

Run:

```bash
git add QuestKeeper/ContentView.swift QuestKeeper/Views/HomeDungeonBoardView.swift QuestKeeper/Views/QuestListSections.swift QuestKeeperTests/QuestActionsTests.swift
git commit -m "feat(ui): pass completion action timestamp"
```

---

### Task 3: Row-Delayed Battle Commit

**Files:**
- Modify: `QuestKeeper/Views/QuestListSections.swift`
- Test: `QuestKeeperTests/QuestBattleResolutionTests.swift`

**Interfaces:**
- Consumes: `QuestBattleResolution.shouldAcceptCompletion(isResolving:)`
- Consumes: `QuestBattleResolution.defeatedPhaseDelay`
- Consumes: `QuestBattleResolution.commitDelay`
- Produces: row-local `isResolvingBattle` state.
- Produces: delayed single invocation of `onComplete(quest, completedAt)`.

- [ ] **Step 1: Add policy coverage for delay separation**

Append to `QuestKeeperTests/QuestBattleResolutionTests.swift`:

```swift
    @Test("commit waits after defeated phase becomes visible")
    func commitWaitsAfterDefeatedPhaseBecomesVisible() {
        let visibleDefeatedDuration = QuestBattleResolution.commitDelay - QuestBattleResolution.defeatedPhaseDelay

        #expect(visibleDefeatedDuration >= 0.4)
    }
```

- [ ] **Step 2: Run policy tests**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/QuestBattleResolutionTests -quiet
```

Expected: PASS.

- [ ] **Step 3: Add resolving state to SwipeableQuestRow**

In `QuestKeeper/Views/QuestListSections.swift`, add state:

```swift
@State private var battlePhase: QuestBattlePhase = .idle
@State private var isResolvingBattle = false
@State private var battleTask: Task<Void, Never>?
```

- [ ] **Step 4: Replace immediate completion with delayed battle**

Change the complete action body to:

```swift
completeWithBattle()
```

Add this helper inside `SwipeableQuestRow`:

```swift
private func completeWithBattle() {
    guard QuestBattleResolution.shouldAcceptCompletion(isResolving: isResolvingBattle) else { return }

    let completedAt = Date.now
    isResolvingBattle = true
    battleTask?.cancel()
    withAnimation(.snappy(duration: 0.18)) {
        offset = 0
        battlePhase = .striking
    }

    battleTask = Task { @MainActor in
        try? await Task.sleep(for: .seconds(QuestBattleResolution.defeatedPhaseDelay))
        guard !Task.isCancelled else { return }
        withAnimation(.snappy(duration: 0.2)) {
            battlePhase = .defeated
        }

        let remainingDelay = QuestBattleResolution.commitDelay - QuestBattleResolution.defeatedPhaseDelay
        try? await Task.sleep(for: .seconds(remainingDelay))
        guard !Task.isCancelled else { return }
        onComplete(quest, completedAt)
    }
}
```

- [ ] **Step 5: Disable interactions while resolving**

Update tap and delete paths in `SwipeableQuestRow`:

```swift
.onTapGesture {
    guard !isResolvingBattle else { return }
    if offset == 0 {
        onEdit(quest)
    } else {
        reset()
    }
}
```

Use this delete action body:

```swift
guard !isResolvingBattle else { return }
reset()
onDelete(quest)
```

Update accessibility actions:

```swift
.accessibilityAction(named: "완료") { completeWithBattle() }
.accessibilityAction(named: "삭제") {
    guard !isResolvingBattle else { return }
    onDelete(quest)
}
```

- [ ] **Step 6: Pass battle phase to QuestRow and block gestures while resolving**

Change the row call:

```swift
QuestRow(quest: quest, now: now, battlePhase: battlePhase)
```

Update gesture handlers:

```swift
.onChanged { value in
    guard !isResolvingBattle else { return }
    guard shouldTrackSwipe(value.translation) else { return }
    isTrackingSwipe = true
    offset = SwipeRevealState.offset(for: value.translation.width)
}
.onEnded { value in
    guard !isResolvingBattle else { return }
    guard isTrackingSwipe else { return }
    isTrackingSwipe = false

    if let side = SwipeRevealState.revealedSide(for: value.translation.width) {
        withAnimation(.snappy(duration: 0.18)) {
            offset = SwipeRevealState.restingOffset(for: side)
        }
    } else {
        reset()
    }
}
```

- [ ] **Step 7: Reset transient state when the row identity changes**

Attach this to the row container:

```swift
.onChange(of: quest.id) { _, _ in
    battleTask?.cancel()
    battleTask = nil
    battlePhase = .idle
    isResolvingBattle = false
    offset = 0
}
```

- [ ] **Step 8: Run focused battle policy tests**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/QuestBattleResolutionTests -quiet
```

Expected: PASS.

- [ ] **Step 9: Commit Task 3**

Run:

```bash
git add QuestKeeper/Views/QuestListSections.swift QuestKeeperTests/QuestBattleResolutionTests.swift
git commit -m "feat(ui): delay quest completion for battle feedback"
```

---

### Task 4: Battle Row Presentation

**Files:**
- Modify: `QuestKeeper/Views/QuestRow.swift`
- Modify: `QuestKeeper/Views/QuestListSections.swift`

**Interfaces:**
- Consumes: `QuestBattlePhase`
- Produces: `QuestRow.init(quest: Quest, now: Date, battlePhase: QuestBattlePhase = .idle)`
- Preserves: default idle rendering for all existing callers.

- [ ] **Step 1: Add battle phase input**

Change `QuestRow` declaration:

```swift
struct QuestRow: View {
    let quest: Quest
    let now: Date
    let battlePhase: QuestBattlePhase

    init(quest: Quest, now: Date, battlePhase: QuestBattlePhase = .idle) {
        self.quest = quest
        self.now = now
        self.battlePhase = battlePhase
    }
```

- [ ] **Step 2: Dim text during defeated phase**

Use the phase when rendering title and metadata:

```swift
let isDefeated = battlePhase == .defeated
```

Change title foreground:

```swift
.foregroundStyle(isDefeated ? .white.opacity(0.58) : .white)
```

Change countdown foreground:

```swift
.foregroundStyle(isDefeated ? Color.white.opacity(0.48) : tone.tint)
```

- [ ] **Step 3: Add victory badge**

In the trailing `VStack`, replace the fixed contents with:

```swift
VStack(alignment: .trailing, spacing: 8) {
    if battlePhase == .defeated {
        Text("VICTORY +1")
            .font(.caption2.monospaced().weight(.black))
            .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.35))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.22), in: Capsule())
            .transition(.scale.combined(with: .opacity))
    } else {
        MobLevelBadge(level: level)
    }
    MonsterGlyph(level: level, battlePhase: battlePhase)
}
```

- [ ] **Step 4: Animate monster glyph by phase**

Change `MonsterGlyph`:

```swift
struct MonsterGlyph: View {
    let level: Int
    let battlePhase: QuestBattlePhase

    init(level: Int, battlePhase: QuestBattlePhase = .idle) {
        self.level = level
        self.battlePhase = battlePhase
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.title3)
            .foregroundStyle(tint)
            .frame(width: 28, height: 28)
            .scaleEffect(battlePhase == .striking ? 1.22 : battlePhase == .defeated ? 0.82 : 1)
            .rotationEffect(.degrees(battlePhase == .striking ? -8 : battlePhase == .defeated ? 10 : 0))
            .opacity(battlePhase == .defeated ? 0.35 : 1)
            .accessibilityLabel("몹 레벨 \(level)")
    }
```

- [ ] **Step 5: Add resolving accessibility value**

In `SwipeableQuestRow`, append:

```swift
.accessibilityValue(isResolvingBattle ? "완료 처리 중" : "")
```

- [ ] **Step 6: Run focused tests for compile coverage**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/QuestBattleResolutionTests -quiet
```

Expected: PASS and compile succeeds.

- [ ] **Step 7: Commit Task 4**

Run:

```bash
git add QuestKeeper/Views/QuestRow.swift QuestKeeper/Views/QuestListSections.swift
git commit -m "feat(ui): render quest row battle feedback"
```

---

### Task 5: Final Verification

**Files:**
- Validate only.

**Interfaces:**
- Verifies all prior tasks together.

- [ ] **Step 1: Run full QuestKeeper tests**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests -quiet
```

Expected: PASS.

- [ ] **Step 2: Run app build**

Run:

```bash
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -quiet
```

Expected: build succeeds.

- [ ] **Step 3: Run source and whitespace guards**

Run:

```bash
git diff --check
! rg -n '^\s*(?:@\w+(?:\([^)]*\))?\s*)*(?:private|fileprivate|internal|public|package|open)?\s*(?:var|let)\s+(?:[Hh][Pp]|isDead|graveCount|retryCount|notificationID|isNotificationScheduled|widgetID|mobLevel|monsterType|urgency)\b' QuestKeeper/Models
```

Expected: both commands pass.

- [ ] **Step 4: Manual simulator check**

Run the app on `iPhone 17e`.
Create a pending quest, reveal the leading complete action, tap complete, and verify the row stays visible briefly with battle feedback before disappearing.
Verify delete still works on a separate pending quest and `내일 도전하기` still works on a daily grave.

- [ ] **Step 5: Commit any verification-only doc corrections**

If verification reveals only doc corrections, commit them separately:

```bash
git add docs/specs/008-row-battle-transition.md docs/plans/009-row-battle-transition-implementation-plan.md
git commit -m "docs: refine row battle transition verification"
```

Expected: no commit is needed unless verification updates the docs.
