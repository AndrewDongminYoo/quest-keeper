# Daily Focus Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Build AND-35 as a dormant DEBUG-only daily loop that recommends one to three pending quests, records only explicit confirmations as immutable snapshots, preserves the chosen set for the local day, and reports focus completion and next-day return without contaminating AND-34.

**Architecture:** Add an append-only DailyFocusSelection SwiftData fact and a validating recorder. Keep recommendation, effective-selection derivation, and reporting pure, then pass those values through the existing ContentView and home-board composition only when -dailyFocusLoopEnabled is present in a DEBUG launch. Reuse the existing quest mutation paths and swipe rows.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Swift Testing, XCTest and XCUIAutomation.

## Global Constraints

- Work in the current directory on feature/and-35-daily-focus-loop; do not create a worktree.
- Keep AND-35 disabled in ordinary DEBUG and Release execution during the AND-34 D7 observation hold.
- Do not change Quest, RetentionReport, OnboardingExperimentReport, AND-34 event semantics, widget behavior, or notification behavior.
- Keep Korean comments and user-facing strings in Korean.
- Store confirmations and revisions as immutable facts; never persist recommendations, progress counters, or derived focus state.
- Run at most one Xcode or simulator-heavy job at a time with parallel testing disabled and -jobs 2.
- Do not bypass Git hooks.
- Keep PR #13 out of the AND-35 branch until it reaches main; before Task 6, fetch main and integrate the merged regression fix so the in-memory UI-test launch argument has one canonical history.

---

### Task 1: Persist Immutable Daily Focus Selections

**Files:**

- Create: QuestKeeperShared/DailyFocusSelection.swift
- Create: QuestKeeperShared/DailyFocusSelectionRecorder.swift
- Modify: QuestKeeperShared/QuestModelContainer.swift
- Modify: QuestKeeperTests/RetentionPersistenceTests.swift
- Create: QuestKeeperTests/DailyFocusSelectionRecorderTests.swift

**Interfaces:**

- Produce DailyFocusSelectionKind, DailyFocusSelection, DailyFocusSelectionSnapshot, DailyFocusSelectionRecordResult, and DailyFocusSelectionRecorder.record(selectedQuestIDs:kind:at:calendar:in:).
- Consume one existing RetentionInstallation row, an injected Calendar, and ModelContext.

- [ ] **Step 1: Write failing persistence and recorder tests**

Cover the exact snapshot fields from Spec 014, deterministic ordered UUID encoding, valid confirmation, duplicate no-op, valid revision, zero/four/duplicate-ID rejection, revision-before-confirmation rejection, and quest-store migration.

```swift
let result = DailyFocusSelectionRecorder.record(
    selectedQuestIDs: [firstQuestID, secondQuestID],
    kind: .confirmation,
    at: recordedAt,
    calendar: calendar,
    in: container.mainContext
)
```

- [ ] **Step 2: Run the focused tests and confirm RED**

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,id=CDF2239B-B46C-4A44-A09E-ED656EF7F9EA' -only-testing:QuestKeeperTests/DailyFocusSelectionRecorderTests -only-testing:QuestKeeperTests/RetentionPersistenceTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
```

Expected: compilation fails because the daily-focus model and recorder do not exist.

- [ ] **Step 3: Add the immutable model and recorder**

Implement private-set model properties for id, schemaVersion, installationID, localDayKey, timeZoneIdentifier, selectedQuestIDsData, recordedAt, and kindRawValue.
Encode an ordered array of UUID strings as compact JSON.
Derive a yyyy-MM-dd key with an en_US_POSIX Gregorian formatter using the injected time zone.
Return inserted(snapshot), unchanged(snapshot), or failed.
Add DailyFocusSelection.self to QuestModelContainer and explicit test schemas.

- [ ] **Step 4: Run the focused tests and confirm GREEN**

Run the Step 2 command.

- [ ] **Step 5: Commit**

```bash
git add QuestKeeperShared/DailyFocusSelection.swift QuestKeeperShared/DailyFocusSelectionRecorder.swift QuestKeeperShared/QuestModelContainer.swift QuestKeeperTests/RetentionPersistenceTests.swift QuestKeeperTests/DailyFocusSelectionRecorderTests.swift
git commit -m "feat(focus): persist daily selections"
```

### Task 2: Derive Recommendations And Effective Daily State

**Files:**

- Create: QuestKeeper/DailyFocus/DailyFocusState.swift
- Create: QuestKeeperTests/DailyFocusStateTests.swift

**Interfaces:**

- Consume QuestSnapshot arrays, DailyFocusSelectionSnapshot arrays, Date, and Calendar.
- Produce DailyFocusPresentationState, DailyFocusState.recommend, and DailyFocusState.make with ordered quest IDs.

- [ ] **Step 1: Write failing derivation tests**

Cover nearest deadline, higher importance, UUID tie-break, one-to-three cap, empty input, completed/grave exclusion, latest snapshot ordering by recordedAt then UUID, completed focus retention, deleted-ID filtering, and next-day reset.

```swift
nonisolated enum DailyFocusPresentationState: Equatable, Sendable {
    case disabled
    case empty
    case recommended([UUID])
    case confirmed(selectedQuestIDs: [UUID], completedQuestIDs: Set<UUID>)
}
```

- [ ] **Step 2: Run the focused tests and confirm RED**

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,id=CDF2239B-B46C-4A44-A09E-ED656EF7F9EA' -only-testing:QuestKeeperTests/DailyFocusStateTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
```

- [ ] **Step 3: Implement pure derivation**

Use QuestSnapshot.outcome(at:) == .pending for candidates.
Sort by deadline ascending, importance descending, and lowercase UUID string ascending.
Treat only supported, decodable snapshots matching the current localDayKey as valid.
Keep historical deleted IDs in snapshots but filter them from visible selected IDs.

- [ ] **Step 4: Run the focused tests and confirm GREEN**

Run the Step 2 command.

- [ ] **Step 5: Commit**

```bash
git add QuestKeeper/DailyFocus/DailyFocusState.swift QuestKeeperTests/DailyFocusStateTests.swift
git commit -m "feat(focus): derive daily recommendations"
```

### Task 3: Calculate The Pure Daily Focus Report

**Files:**

- Create: QuestKeeperShared/DailyFocusReport.swift
- Create: QuestKeeperTests/DailyFocusReportTests.swift

**Interfaces:**

- Consume selection, installation, and retention-event snapshots plus asOf, Calendar, and DateInterval.
- Produce DailyFocusReport.make, DailyFocusMetrics, and DailyFocusDataQuality as Codable, Equatable, Sendable values.

- [ ] **Step 1: Write failing report tests**

Cover selection rate, unique selected-quest completion after first inclusion, selected-day completion, revision rate, exact-next-day revisit, current-day and D1 right-censoring, duplicate/conflicting snapshots, unsupported schema, malformed payload, missing installation, pre-confirmation revision, future rows, and empty denominators.

```swift
let report = DailyFocusReport.make(
    selections: selections,
    installations: installations,
    events: events,
    asOf: asOf,
    calendar: calendar,
    reportingInterval: interval
)
```

- [ ] **Step 2: Run focused tests and confirm RED**

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,id=CDF2239B-B46C-4A44-A09E-ED656EF7F9EA' -only-testing:QuestKeeperTests/DailyFocusReportTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
```

- [ ] **Step 3: Implement canonicalization and formulas**

Reuse RetentionRate.
Canonicalize supported installations and existing retention events under their current contracts.
Group selection snapshots by installation and local day, keep the first confirmation and ordered revisions, and mark quality partial for every rejected row class in Spec 014.
Do not add a RetentionEventName or write daily-focus-v1.json while rollout is dormant.

- [ ] **Step 4: Run focused tests and confirm GREEN**

Run the Step 2 command.

- [ ] **Step 5: Commit**

```bash
git add QuestKeeperShared/DailyFocusReport.swift QuestKeeperTests/DailyFocusReportTests.swift
git commit -m "feat(metrics): report daily focus outcomes"
```

### Task 4: Gate And Wire Daily Focus State

**Files:**

- Modify: QuestKeeper/QuestKeeperApp.swift
- Modify: QuestKeeper/ContentView.swift
- Modify: QuestKeeperTests/QuestKeeperAppTests.swift
- Create: QuestKeeperTests/DailyFocusIntegrationTests.swift

**Interfaces:**

- Produce dailyFocusLoopEnabled(arguments:) and pass the boolean from QuestKeeperApp to ContentView.
- Consume the model query, pure derivation, and recorder from Tasks 1 and 2.

- [ ] **Step 1: Write failing gate and integration tests**

Require only an exact -dailyFocusLoopEnabled argument to enable the DEBUG path.
Require disabled state to avoid recording and enabled state to save one confirmation and restore it from a fresh context.

- [ ] **Step 2: Run focused tests and confirm RED**

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,id=CDF2239B-B46C-4A44-A09E-ED656EF7F9EA' -only-testing:QuestKeeperTests/QuestKeeperAppTests -only-testing:QuestKeeperTests/DailyFocusIntegrationTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
```

- [ ] **Step 3: Implement the dormant gate and wiring**

In DEBUG, initialize the flag from ProcessInfo arguments; in Release, pass false.
Query DailyFocusSelection in ContentView, derive presentation inside TimelineView, and record confirmation or revision only from explicit callbacks.
On recorder failure, keep the ordinary full dungeon.

- [ ] **Step 4: Run focused tests and confirm GREEN**

Run the Step 2 command.

- [ ] **Step 5: Commit**

```bash
git add QuestKeeper/QuestKeeperApp.swift QuestKeeper/ContentView.swift QuestKeeperTests/QuestKeeperAppTests.swift QuestKeeperTests/DailyFocusIntegrationTests.swift
git commit -m "feat(focus): gate daily loop integration"
```

### Task 5: Add Explicit Choice And Confirmed Focus UI

**Files:**

- Create: QuestKeeper/Views/DailyFocusSelectionSheet.swift
- Modify: QuestKeeper/Views/HomeDungeonBoardView.swift
- Modify: QuestKeeper/Views/QuestListSections.swift
- Modify: QuestKeeper/ContentView.swift
- Modify: QuestKeeperTests/DailyFocusStateTests.swift

**Interfaces:**

- DailyFocusSelectionSheet consumes ordered pending quests, initial selected IDs, and onSave: ([UUID]) -> Void.
- HomeDungeonBoardView consumes DailyFocusPresentationState and confirm/edit callbacks without owning persistence.
- QuestListSections continues to own the existing swipe row implementation.

- [ ] **Step 1: Add failing UI-state tests**

Cover one-to-three validation, the non-focus pending partition, completed progress, and deletion producing an empty resolvable focus set.

- [ ] **Step 2: Run focused tests and confirm RED**

Run the Task 2 focused-test command.

- [ ] **Step 3: Implement the selection sheet and board states**

Before confirmation, show recommendations while leaving ordinary dungeon rows usable.
Expose 핵심 퀘스트 수정 and 오늘 이대로 시작.
After confirmation, render 오늘의 핵심 퀘스트, progress such as 1/3, completed selected quests without replacement, 핵심 퀘스트 수정, collapsed 나머지 퀘스트 N개, and the separate daily-grave section.
Disable save for zero or more than three selections and announce the selected count through accessibility.

- [ ] **Step 4: Run tests and build**

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,id=CDF2239B-B46C-4A44-A09E-ED656EF7F9EA' -only-testing:QuestKeeperTests/DailyFocusStateTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
xcodebuild build -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,id=CDF2239B-B46C-4A44-A09E-ED656EF7F9EA' -jobs 2
```

Run these sequentially, never concurrently.

- [ ] **Step 5: Commit**

```bash
git add QuestKeeper/Views/DailyFocusSelectionSheet.swift QuestKeeper/Views/HomeDungeonBoardView.swift QuestKeeper/Views/QuestListSections.swift QuestKeeper/ContentView.swift QuestKeeperTests/DailyFocusStateTests.swift
git commit -m "feat(focus): add explicit daily choice UI"
```

### Task 6: Restore Retry Icons And Add End-To-End Coverage

**Files:**

- Modify: QuestKeeper/Views/QuestRow.swift
- Modify: QuestKeeper/Views/QuestResolutionView.swift
- Modify: QuestKeeperUITests/QuestKeeperUITests.swift

**Prerequisite:** PR #13 is merged to main and the feature branch has integrated that main commit without recreating the regression patch.

- [ ] **Step 1: Restore the two retry labels**

Use Label("내일 도전하기", systemImage: "arrow.uturn.forward") in both existing surfaces.
Do not delete the pixel asset or alter other icons.

- [ ] **Step 2: Add deterministic UI tests**

Launch with -uiTestingInMemoryStore, -onboardingVariant control, and -dailyFocusLoopEnabled.
Cover recommendation without selection, explicit confirmation, swipe completion progress without replacement, revision, remaining disclosure, and launch without the focus argument showing the ordinary dungeon.
Do not assert same-day persistence across process relaunch with an in-memory store; cover persistence through the integration test using an on-disk temporary store.

- [ ] **Step 3: Run focused UI tests**

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,id=CDF2239B-B46C-4A44-A09E-ED656EF7F9EA' -only-testing:QuestKeeperUITests/QuestKeeperUITests/testDailyFocusExplicitConfirmationAndCompletion -only-testing:QuestKeeperUITests/QuestKeeperUITests/testDailyFocusRemainsDormantWithoutLaunchArgument -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
```

- [ ] **Step 4: Commit**

```bash
git add QuestKeeper/Views/QuestRow.swift QuestKeeper/Views/QuestResolutionView.swift QuestKeeperUITests/QuestKeeperUITests.swift
git commit -m "test(focus): cover daily choice flow"
```

### Task 7: Full Verification And Manual Visual QA

**Files:**

- Modify only files required by concrete verification findings.

- [ ] **Step 1: Run all unit tests**

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,id=CDF2239B-B46C-4A44-A09E-ED656EF7F9EA' -only-testing:QuestKeeperTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
```

- [ ] **Step 2: Run the complete UI test target**

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,id=CDF2239B-B46C-4A44-A09E-ED656EF7F9EA' -only-testing:QuestKeeperUITests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
```

- [ ] **Step 3: Build the widget scheme**

```bash
xcodebuild build -project QuestKeeper.xcodeproj -scheme QuestKeeperWidget -destination 'generic/platform=iOS Simulator' -jobs 2
```

- [ ] **Step 4: Perform simulator and visual QA**

Launch with the focus argument and create more than three pending quests.
Inspect recommendation, edit and confirm one to three items, complete a selected quest by swiping right, expand remaining quests, revise the selection, relaunch on the same day with persistent storage, and inspect both 내일 도전하기 surfaces.
Capture recommendation, confirmed, completion, revision, remaining-expanded, and dormant ordinary-flow states.
Run two independent read-only visual checks on fresh captures and resolve every blocking CJK, layout, accessibility, or interaction finding.

- [ ] **Step 5: Verify final branch state**

```bash
git diff --check origin/main...HEAD
git status --short
git log --oneline origin/main..HEAD
```

Expected: diff check passes, the working tree is clean, and commits contain only AND-35 plus its approved spec and plan.
