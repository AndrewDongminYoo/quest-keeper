# Integration Verification & Retrospective Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close Phase 5 by proving the daily dungeon, notifications, activation replay, and widget snapshot lifecycle work together from raw quest facts.

**Architecture:** Keep production code mostly unchanged unless tests expose a real integration gap. Add one integration-focused test file that composes existing pure derivation, action, notification, and widget snapshot seams. Add manual evidence documents under `docs/notes/` for WidgetKit and notification behaviors that depend on iOS system timing.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, UserNotifications, WidgetKit, App Groups, Swift Testing, XcodeBuildMCP or `xcodebuild` on iOS Simulator `iPhone 17e`.

## Global Constraints

- Store only raw facts on `Quest`: `id`, `title`, `deadline`, `completedAt`, `importance`.
- Do not store HP, `isDead`, grave count, retry count, monster type, urgency, mob level, notification IDs, notification scheduled state, widget IDs, or widget-derived state on `Quest`.
- Phase 5 adds verification and evidence only; it does not add new gameplay mechanics.
- The widget continues to read `widget-dungeon-snapshot.json`; it does not open SwiftData.
- App Group identifier remains `group.kr.donminzzi.QuestKeeper`.
- No third-party dependencies.
- Korean user-facing strings stay Korean.
- Use TDD for behavior changes: add failing Swift Testing coverage before production changes.

---

## File Structure

- Create `QuestKeeperTests/IntegrationVerificationTests.swift`
  - End-to-end-style tests over raw facts, app derivation, widget derivation, activation replay, and source invariants.
- Modify `QuestKeeper/Derivation/HeroDerivation.swift`
  - Add an optional `calendar: Calendar = .current` parameter to `HeroDerivation.state`.
- Create `docs/notes/006-phase-5-verification-log.md`
  - Manual simulator/device checklist and evidence log.
- Create `docs/notes/006-phase-5-retrospective.md`
  - Short learning closeout and follow-up backlog.
- Modify production files only if the new tests expose a real still-valid integration gap.

---

### Task 1: Cross-Surface Integration Tests

**Files:**
- Create: `QuestKeeperTests/IntegrationVerificationTests.swift`
- Modify: `QuestKeeper/Derivation/HeroDerivation.swift`
- Modify: `QuestKeeperShared/WidgetDungeonDerivation.swift`

**Interfaces:**
- Consumes:
  - `QuestSnapshot(id:deadline:completedAt:importance:)`
  - `HeroDerivation.state(quests:now:lastOpened:calendar:) -> HeroState`
  - `WidgetDungeonPayload(schemaVersion:generatedAt:quests:)`
  - `WidgetQuestPayload(id:title:deadline:completedAt:importanceRawValue:)`
  - `WidgetDungeonDerivation.derive(payload:at:calendar:) -> WidgetDungeonEntryState`
- Produces:
  - Regression coverage that app and widget derivation agree on victories and daily graves.
  - Regression coverage that complete, retry tomorrow, and delete-style payload exclusion keep widget facts aligned with raw quest mutations.

- [ ] **Step 1: Write the failing integration tests**

Create `QuestKeeperTests/IntegrationVerificationTests.swift`:

```swift
import Foundation
import Testing
@testable import QuestKeeper

@MainActor
struct IntegrationVerificationTests {
    private let now = Date(timeIntervalSinceReferenceDate: 820_584_000)
    private let hour: TimeInterval = 60 * 60
    private let day: TimeInterval = 24 * 60 * 60

    @Test("app and widget derive the same victories and visible daily graves")
    func appAndWidgetDeriveSameVictoriesAndDailyGraves() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        let pendingID = UUID()
        let todayGraveID = UUID()
        let oldGraveID = UUID()
        let victoryID = UUID()
        let lateCompletionID = UUID()

        let snapshots = [
            snapshot(id: pendingID, deadline: now.addingTimeInterval(hour), completedAt: nil, importance: .high),
            snapshot(id: todayGraveID, deadline: now.addingTimeInterval(-hour), completedAt: nil, importance: .medium),
            snapshot(id: oldGraveID, deadline: now.addingTimeInterval(-day), completedAt: nil, importance: .medium),
            snapshot(id: victoryID, deadline: now.addingTimeInterval(hour), completedAt: now.addingTimeInterval(-hour), importance: .low),
            snapshot(id: lateCompletionID, deadline: now.addingTimeInterval(-2 * hour), completedAt: now.addingTimeInterval(-hour), importance: .high),
        ]
        let payload = WidgetDungeonPayload(
            schemaVersion: WidgetDungeonPayload.currentSchemaVersion,
            generatedAt: now,
            quests: [
                widgetQuest(id: pendingID, title: "진행 중", deadline: now.addingTimeInterval(hour), completedAt: nil, importance: .high),
                widgetQuest(id: todayGraveID, title: "오늘 놓침", deadline: now.addingTimeInterval(-hour), completedAt: nil, importance: .medium),
                widgetQuest(id: oldGraveID, title: "어제 놓침", deadline: now.addingTimeInterval(-day), completedAt: nil, importance: .medium),
                widgetQuest(id: victoryID, title: "승리", deadline: now.addingTimeInterval(hour), completedAt: now.addingTimeInterval(-hour), importance: .low),
                widgetQuest(id: lateCompletionID, title: "늦은 완료", deadline: now.addingTimeInterval(-2 * hour), completedAt: now.addingTimeInterval(-hour), importance: .high),
            ]
        )

        let hero = HeroDerivation.state(
            quests: snapshots,
            now: now,
            lastOpened: now.addingTimeInterval(-3 * day),
            calendar: calendar
        )
        let widget = WidgetDungeonDerivation.derive(payload: payload, at: now, calendar: calendar)

        #expect(hero.totalVictories == widget.totalVictories)
        #expect(hero.dailyGraves == [todayGraveID, lateCompletionID])
        #expect(widget.dailyGraves.map(\.id) == [todayGraveID, lateCompletionID])
        #expect(hero.dailyGraves == widget.dailyGraves.map(\.id))
        #expect(widget.activeMobs.map(\.id) == [pendingID])
        #expect(widget.dailyGraves.map(\.id).contains(oldGraveID) == false)
        #expect(widget.activeMobs.map(\.id).contains(lateCompletionID) == false)
    }

    @Test("quest mutations keep widget payload facts aligned")
    func questMutationsKeepWidgetPayloadFactsAligned() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        let questID = UUID()
        let quest = Quest(
            id: questID,
            title: "통합 검증",
            deadline: now.addingTimeInterval(hour),
            importance: .high
        )

        let initialPayload = WidgetDungeonPayload.make(from: [quest], generatedAt: now)
        let initialState = WidgetDungeonDerivation.derive(
            payload: initialPayload,
            at: now,
            calendar: calendar
        )
        #expect(initialPayload.quests.map(\.id) == [questID])
        #expect(initialState.activeMobs.map(\.id) == [questID])

        QuestActions.complete(quest, at: now)
        let completedPayload = WidgetDungeonPayload.make(from: [quest], generatedAt: now)
        let completedState = WidgetDungeonDerivation.derive(
            payload: completedPayload,
            at: now,
            calendar: calendar
        )
        #expect(completedPayload.quests.first?.completedAt == now)
        #expect(completedState.totalVictories == 1)
        #expect(completedState.activeMobs.isEmpty)

        QuestActions.retryTomorrow(quest, now: now, calendar: calendar)
        let retriedPayload = WidgetDungeonPayload.make(from: [quest], generatedAt: now)
        let retriedState = WidgetDungeonDerivation.derive(
            payload: retriedPayload,
            at: now,
            calendar: calendar
        )
        #expect(retriedPayload.quests.first?.completedAt == nil)
        #expect(retriedPayload.quests.first?.deadline ?? now > now)
        #expect(retriedState.activeMobs.map(\.id) == [questID])

        let deletedPayload = WidgetDungeonPayload.make(
            from: [quest],
            excluding: questID,
            generatedAt: now
        )
        #expect(deletedPayload.quests.isEmpty)
    }

    @Test("activation replay reports missed quests once after long inactivity")
    func activationReplayReportsMissedQuestsOnceAfterLongInactivity() {
        let missedWhileAwayID = UUID()
        let missedBeforeAwayID = UUID()
        let completedID = UUID()
        let lastOpened = now.addingTimeInterval(-30 * day)
        let quests = [
            snapshot(id: missedWhileAwayID, deadline: now.addingTimeInterval(-2 * day), completedAt: nil, importance: .medium),
            snapshot(id: missedBeforeAwayID, deadline: now.addingTimeInterval(-40 * day), completedAt: nil, importance: .medium),
            snapshot(id: completedID, deadline: now.addingTimeInterval(-2 * day), completedAt: now.addingTimeInterval(-3 * day), importance: .medium),
        ]

        let first = reconstructOnActivation(quests: quests, now: now, previousLastOpened: lastOpened)
        let second = reconstructOnActivation(quests: quests, now: now, previousLastOpened: first.newLastOpened)

        #expect(first.deaths == [missedWhileAwayID])
        #expect(second.deaths.isEmpty)
    }

    private func snapshot(
        id: UUID,
        deadline: Date,
        completedAt: Date?,
        importance: Importance
    ) -> QuestSnapshot {
        QuestSnapshot(id: id, deadline: deadline, completedAt: completedAt, importance: importance)
    }

    private func widgetQuest(
        id: UUID,
        title: String,
        deadline: Date,
        completedAt: Date?,
        importance: Importance
    ) -> WidgetQuestPayload {
        WidgetQuestPayload(
            id: id,
            title: title,
            deadline: deadline,
            completedAt: completedAt,
            importanceRawValue: importance.rawValue
        )
    }
}
```

- [ ] **Step 2: Run the focused test against the implemented integration state**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/IntegrationVerificationTests
```

Expected: PASS with the current Phase 5 implementation.
`HeroDerivation.state` already accepts `calendar:` and the widget late-completion behavior is aligned with the app derivation policy.

- [ ] **Step 3: Record the implemented integration alignment**

The app derivation entry point now accepts an explicit calendar for daily-grave visibility:

```swift
static func state(
    quests: [QuestSnapshot],
    now: Date,
    lastOpened: Date,
    calendar: Calendar = .current
) -> HeroState {
    var totalVictories = 0
    var dailyGraves: [UUID] = []
    for quest in quests {
        switch quest.outcome(at: now) {
        case .victory:
            totalVictories += 1
        case .grave:
            if quest.isVisibleDailyGrave(at: now, calendar: calendar) {
                dailyGraves.append(quest.id)
            }
        case .pending: break
        }
    }

    let deathsWhileAway = quests
        .filter { $0.deadline > lastOpened && $0.deadline <= now && $0.outcome(at: now) == .grave }
        .map(\.id)

    return HeroState(totalVictories: totalVictories, dailyGraves: dailyGraves, deathsWhileAway: deathsWhileAway)
}
```

Widget derivation is aligned with the Phase 5 policy that late completions remain graves when their deadline is on the current local day.
It builds the `WidgetMobState` before the completion branch and routes late completions into `dailyGraves`:

```swift
let urgencyLevel = urgencyLevel(deadline: quest.deadline, at: date)
let mob = WidgetMobState(
    id: quest.id,
    title: quest.title,
    deadline: quest.deadline,
    importanceRawValue: quest.importanceRawValue,
    urgencyLevel: urgencyLevel,
    mobLevel: mobLevel(
        deadline: quest.deadline,
        importanceRawValue: quest.importanceRawValue,
        at: date
    )
)

if let completedAt = quest.completedAt {
    if completedAt <= quest.deadline {
        totalVictories += 1
    } else if calendar.isDate(quest.deadline, inSameDayAs: date) {
        dailyGraves.append(mob)
    }
    continue
}
```

Do not add derived fields to `Quest`.
Do not add a new persisted status flag.

Examples of unacceptable fixes:

```swift
quest.mobLevel = computedLevel
quest.isNotificationScheduled = true
quest.retryCount += 1
```

- [ ] **Step 4: Run the focused test to verify GREEN**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/IntegrationVerificationTests
```

Expected: PASS with all tests in `IntegrationVerificationTests` passing.

- [ ] **Step 5: Commit Task 1**

Run:

```bash
git add QuestKeeper/Derivation/HeroDerivation.swift QuestKeeperShared/WidgetDungeonDerivation.swift QuestKeeperTests/IntegrationVerificationTests.swift
git commit -m "test(integration): verify app and widget lifecycle invariants"
```

Expected: a commit containing only the new integration test file and any production fix required by a real failing test.

---

### Task 2: Source-Guard and Full Automated Verification

**Files:**
- Modify only if required by real failures found by the commands below.

**Interfaces:**
- Consumes:
  - `QuestKeeper/Models/Quest.swift`
  - all `QuestKeeperTests`
- Produces:
  - Fresh verification evidence for the full Phase 5 automated gate.

- [ ] **Step 1: Run the raw-facts source guard**

Run:

```bash
! rg -n '^\s*(?:@\w+(?:\([^)]*\))?\s*)*(?:private|fileprivate|internal|public|package|open)?\s*(?:var|let)\s+(?:[Hh][Pp]|isDead|graveCount|retryCount|notificationID|isNotificationScheduled|widgetID|mobLevel|monsterType|urgency)\b' QuestKeeper/Models
```

Expected: no output and exit code 0.

- [ ] **Step 2: Fix only actual source-guard violations**

If the guard finds a forbidden stored field on `Quest`, remove the stored field and derive that value from `QuestSnapshot`, `HeroDerivation`, `QuestNotificationPlanner`, or `WidgetDungeonDerivation`.
For example, replace a stored notification identifier with deterministic planner usage:

```swift
let identifiers = QuestNotificationPlanner.identifiers(for: quest.id)
```

Expected: rerunning the guard prints no matches.

- [ ] **Step 3: Run all unit tests**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests
```

Expected: `QuestKeeperTests` passes with zero failures.

- [ ] **Step 4: Run simulator build**

Run:

```bash
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'
```

Expected: build succeeds with no errors.

- [ ] **Step 5: Run diff whitespace check**

Run:

```bash
git diff --check
```

Expected: no output.

- [ ] **Step 6: Commit any fixes from Task 2**

If Task 2 required code changes, commit them:

```bash
git add QuestKeeper QuestKeeperTests
git commit -m "fix(integration): preserve raw-facts lifecycle invariants"
```

If no code changes were required, do not create an empty commit.

---

### Task 3: Manual Verification Log

**Files:**
- Create: `docs/notes/006-phase-5-verification-log.md`

**Interfaces:**
- Consumes:
  - Spec scenarios from `docs/specs/006-integration-verification.md`
  - The app installed from the current commit
- Produces:
  - Manual evidence for notification delivery, WidgetKit refresh, and App Group behavior.

- [ ] **Step 1: Create the verification log template**

Create `docs/notes/006-phase-5-verification-log.md`:

```markdown
# Phase 5 Verification Log

Status: in progress
Source commit:
Date:
Tester:

## Environment

- Device or simulator:
- OS version:
- Xcode version:
- Notification authorization:
- Widget installed:
- App Group identifier observed:

## Automated Gate

- `xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests`:
- `xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'`:
- `git diff --check`:
- Raw-facts source guard:

## Manual Scenarios

### 1. Fresh Install And First Launch

Steps:
1. Install a clean build.
2. Launch the app.
3. Grant or deny notification permission explicitly.
4. Confirm the empty dungeon copy is safe and no crash occurs.

Observed:

Result:

### 2. Create Due-Soon And Later Quests

Steps:
1. Create one quest due within the due-soon window.
2. Create one quest due later.
3. Inspect pending notification requests in the debugger or app logs.
4. Add or refresh the QuestKeeper widget.

Observed:

Result:

### 3. Edit Deadline

Steps:
1. Edit an existing quest deadline.
2. Confirm old notification identifiers are removed before replacement requests are scheduled.
3. Confirm the widget reflects the updated deadline after reload or normal refresh.

Observed:

Result:

### 4. Complete Quest

Steps:
1. Complete a pending quest.
2. Confirm pending and delivered QuestKeeper notifications for that quest are removed.
3. Confirm total victories increase.
4. Confirm the widget no longer shows the quest as active.

Observed:

Result:

### 5. Retry Tomorrow

Steps:
1. Use `내일 도전하기` on a visible daily grave.
2. Confirm the deadline moves to tomorrow and `completedAt` clears.
3. Confirm notifications are recreated for the new future deadline.
4. Confirm the widget shows the quest as active again.

Observed:

Result:

### 6. Delete Quest

Steps:
1. Delete a pending quest.
2. Confirm notifications are removed.
3. Confirm the widget payload no longer includes the quest.

Observed:

Result:

### 7. Reopen After Missed Deadline

Steps:
1. Create a quest with a near deadline.
2. Leave the app inactive until after the deadline.
3. Reopen the app.
4. Confirm the transient death/replay appears once.
5. Reopen again and confirm the same replay does not repeat.

Observed:

Result:

## Notes

- WidgetKit refresh timing limitations:
- Notification delivery timing limitations:
- Follow-up issues:
```

- [ ] **Step 2: Fill source commit and automated gate results**

Run:

```bash
git rev-parse HEAD
```

Paste the resulting commit into `Source commit`.
Fill the automated gate rows using the fresh results from Task 2.

- [ ] **Step 3: Perform manual scenarios and fill observed results**

Run through each manual scenario on the selected simulator or device.
Use `pass`, `fail`, or `blocked` in each `Result:` field.
For `blocked`, write the concrete blocker in `Observed:`.

- [ ] **Step 4: Commit Task 3**

Run:

```bash
git add docs/notes/006-phase-5-verification-log.md
git commit -m "docs: record phase 5 verification evidence"
```

Expected: a docs-only commit.

---

### Task 4: Retrospective Closeout

**Files:**
- Create: `docs/notes/006-phase-5-retrospective.md`

**Interfaces:**
- Consumes:
  - `BLUEPRINT.md`
  - `docs/specs/006-integration-verification.md`
  - `docs/notes/006-phase-5-verification-log.md`
- Produces:
  - A short milestone closeout note and next backlog recommendation.

- [ ] **Step 1: Create the retrospective**

Create `docs/notes/006-phase-5-retrospective.md`:

```markdown
# Phase 5 Retrospective

Status: draft
Source commit:

## Native Boundaries Crossed

- SwiftData raw facts:
- Deterministic derivation:
- App activation replay:
- UserNotifications lifecycle:
- App Group snapshot bridge:
- WidgetKit timeline rendering:

## Most Error-Prone Boundary

Write the boundary that required the most review or rework.
Include the concrete reason.

## Manual-Only Assumptions

- WidgetKit refresh timing:
- Local notification delivery timing:
- Device signing and App Group provisioning:

## Accepted Shortcuts

- No CloudKit or account system.
- No recurring quest engine.
- No SpriteKit or polished pixel asset pipeline.
- No interactive widget actions.
- Widget uses an App Group JSON cache instead of opening SwiftData.

## Follow-Up Backlog Recommendation

Recommended next item:

Reason:

## Closeout Decision

Choose one:

- Phase 5 accepted:
- Phase 5 blocked:

Evidence:
```

- [ ] **Step 2: Fill the retrospective from actual evidence**

Copy the source commit from Task 3.
Use only observed facts from the verification log and code review history.
Do not turn this into marketing copy.

- [ ] **Step 3: Commit Task 4**

Run:

```bash
git add docs/notes/006-phase-5-retrospective.md
git commit -m "docs: close phase 5 native boundary retrospective"
```

Expected: a docs-only commit.

---

### Task 5: Final Phase 5 Gate

**Files:**
- Modify only if final verification exposes a real issue.

**Interfaces:**
- Consumes:
  - all code and docs touched in Tasks 1-4
- Produces:
  - merge-ready Phase 5 branch.

- [ ] **Step 1: Run full automated verification**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'
git diff --check
! rg -n '^\s*(?:@\w+(?:\([^)]*\))?\s*)*(?:private|fileprivate|internal|public|package|open)?\s*(?:var|let)\s+(?:[Hh][Pp]|isDead|graveCount|retryCount|notificationID|isNotificationScheduled|widgetID|mobLevel|monsterType|urgency)\b' QuestKeeper/Models
```

Expected:

- tests pass;
- build succeeds;
- `git diff --check` prints no output;
- source guard prints no matches and exits 0.

- [ ] **Step 2: Verify docs are filled**

Run:

```bash
rg -n "Status: in progress|Status: draft|Source commit:$|Observed:$|Result:$|Recommended next item:$|Reason:$|Evidence:$" docs/notes/006-phase-5-verification-log.md docs/notes/006-phase-5-retrospective.md
```

Expected: no matches for empty placeholders before merge.
If a scenario is blocked, keep `Result: blocked` and write the blocker in `Observed:`.

- [ ] **Step 3: Inspect final diff**

Run:

```bash
git status --short
git diff --stat HEAD
```

Expected: only Phase 5 test/doc changes remain uncommitted.

- [ ] **Step 4: Commit final fixes if any**

If there are final fixes, commit them with the narrowest conventional commit message:

```bash
git add QuestKeeper QuestKeeperTests docs/notes
git commit -m "fix(integration): complete phase 5 verification gate"
```

If there are no final fixes, do not create an empty commit.

- [ ] **Step 5: Prepare PR**

Run:

```bash
git status --short
git log --oneline --decorate -5
```

Expected: clean worktree and a clear sequence of Phase 5 commits.
