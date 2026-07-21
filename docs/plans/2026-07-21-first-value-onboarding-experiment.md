# First-Value Onboarding Experiment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement AND-34 as a stable installation-level 50:50 A/B experiment that compares the current first-use flow with a guided save-and-complete flow without contaminating the established retention baseline.

**Architecture:** Add one immutable SwiftData assignment model beside the existing retention journal, record three privacy-safe experiment events through the canonical recorder, and calculate a separate pure onboarding report over explicit cohort and calendar inputs. Resolve assignment before the first UI is chosen, derive guided re-entry from persisted facts plus one process-local deferral flag, and leave `Quest` and the existing retention formulas unchanged.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Swift Testing, Foundation `Codable`, OSLog, App Groups, XCTest UI automation, Xcode 26 simulator tooling

## Global Constraints

- Work in the current repository directory on `feature/and-34-first-value-onboarding`; do not create another worktree.
- Keep `and-34-first-value-v1` as the only experiment key in this implementation.
- Assign only installations with no `RetentionInstallation`, no assignment, and no persisted `Quest`; never backfill an existing installation.
- Store assignment and measurement facts separately from `Quest`; do not add experiment, onboarding, or derived properties to `Quest`.
- Keep the control UI visually unchanged and preserve every approved Korean string.
- Do not add a third-party analytics or experimentation dependency.
- Do not implement AND-35 or AND-38 while the AND-34 observation window is active.
- Treat fixtures and local reports as exploratory calculation evidence, never population-level uplift evidence.
- Use exact local-calendar D1 and D7 eligibility and right-censored denominators.
- Use `-parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2` for all tests.
- Run only one simulator, Xcode build, or test job at a time.
- Move Linear AND-34 to In Progress before code changes; do not mark it Done until an eventual PR is attached and merged.
- Make one Conventional Commit per task, without Co-Author lines or bypassed hooks.

## File Responsibility Map

- `QuestKeeperShared/ExperimentAssignment.swift` — experiment definition, variant, persistent assignment, and snapshot.
- `QuestKeeperShared/ExperimentAssignmentRecorder.swift` — one-time eligibility, assignment creation, reload, and failure result.
- `QuestKeeperShared/RetentionEvent.swift` and `QuestKeeperShared/RetentionEventRecorder.swift` — three canonical experiment events.
- `QuestKeeperShared/OnboardingExperimentReport.swift` — pure validation, canonicalization, cohort metrics, and Markdown rendering.
- `QuestKeeperShared/OnboardingExperimentStore.swift` — atomic `onboarding-experiment-v1.json` persistence.
- `QuestKeeper/Onboarding/OnboardingFlowState.swift` — pure guided offer/completion reconstruction.
- `QuestKeeper/QuestKeeperApp.swift` and `QuestKeeper/ContentView.swift` — pre-UI assignment and event/UI wiring.
- `QuestKeeper/Views/QuestEditor.swift`, `HomeDungeonBoardView.swift`, `QuestListSections.swift`, and `QuestRow.swift` — guided draft, card, and completion guidance.
- `QuestKeeperTests/Fixtures/OnboardingExperimentFixture.swift` and focused test files — deterministic coverage.
- `docs/notes/013-onboarding-experiment-baseline.md` and `docs/notes/013-onboarding-experiment-verification.md` — synthetic and observed evidence.

---

### Task 1: Persist One Stable Assignment Per Eligible Installation

**Files:**

- Create: `QuestKeeperShared/ExperimentAssignment.swift`
- Create: `QuestKeeperShared/ExperimentAssignmentRecorder.swift`
- Create: `QuestKeeperTests/ExperimentAssignmentRecorderTests.swift`
- Modify: `QuestKeeperShared/QuestModelContainer.swift:13-24`
- Modify: `QuestKeeperTests/RetentionPersistenceTests.swift:13-102`

**Interfaces:**

- Consumes: `RetentionInstallation`, `RetentionInstallationIdentityStore.loadOrCreate()`, `Quest`, and a main-actor `ModelContext`.
- Produces: `OnboardingExperiment.key`, `OnboardingExperimentVariant`, `ExperimentAssignment`, `ExperimentAssignmentSnapshot`, `ExperimentEnrollmentResult`, and `ExperimentAssignmentRecorder.enrollIfEligible(at:in:installationIDProvider:variantSelector:)`.

- [ ] **Step 1: Move AND-34 to In Progress**

Use Linear to update only AND-34, then re-fetch it and require status `In Progress`, assignee `Andrew Yu`, and blocker AND-33 unchanged.

- [ ] **Step 2: Write failing assignment tests**

Create tests that inject fixed UUIDs, dates, and variants:

```swift
let first = ExperimentAssignmentRecorder.enrollIfEligible(
    at: assignedAt,
    in: container.mainContext,
    installationIDProvider: { installationID },
    variantSelector: { .guided }
)
let second = ExperimentAssignmentRecorder.enrollIfEligible(
    at: assignedAt.addingTimeInterval(10),
    in: container.mainContext,
    installationIDProvider: { UUID() },
    variantSelector: { .control }
)

#expect(first.assignment?.variant == .guided)
#expect(second.assignment == first.assignment)
#expect(try container.mainContext.fetch(FetchDescriptor<ExperimentAssignment>()).count == 1)
```

Also test existing installation exclusion, existing quest exclusion, identity-provider failure with no inserted rows, conflicting assignment failure, exact snapshot field labels, persistence beside a quest, and legacy `Quest`-only store migration with an empty assignment table.

- [ ] **Step 3: Verify the focused tests fail for missing types**

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,id=7ED9020C-A21E-425F-AF74-C71C40DA0A13' -only-testing:QuestKeeperTests/ExperimentAssignmentRecorderTests -only-testing:QuestKeeperTests/RetentionPersistenceTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
```

Expected: FAIL because the assignment types do not exist.

- [ ] **Step 4: Add the assignment model and snapshot**

Implement these exact shapes:

```swift
nonisolated enum OnboardingExperiment {
    static let key = "and-34-first-value-v1"
}

nonisolated enum OnboardingExperimentVariant: String, Codable, CaseIterable, Sendable {
    case control
    case guided
}

@Model
final class ExperimentAssignment {
    static let currentSchemaVersion = 1
    var schemaVersion: Int
    var experimentKey: String
    var installationID: UUID
    var variantRawValue: String
    var assignedAt: Date
}

nonisolated struct ExperimentAssignmentSnapshot: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let experimentKey: String
    let installationID: UUID
    let variantRawValue: String
    let assignedAt: Date
    var variant: OnboardingExperimentVariant? { OnboardingExperimentVariant(rawValue: variantRawValue) }
}
```

Provide one initializer that sets all five fields and one computed snapshot.
Expose no mutation method; SwiftData stored `var` properties remain recorder-owned.

- [ ] **Step 5: Implement eligibility and stable reload**

Use this contract:

```swift
nonisolated enum ExperimentEnrollmentResult: Equatable, Sendable {
    case enrolled(ExperimentAssignmentSnapshot)
    case ineligible
    case failed
    var assignment: ExperimentAssignmentSnapshot? {
        guard case .enrolled(let assignment) = self else { return nil }
        return assignment
    }
}

@MainActor
enum ExperimentAssignmentRecorder {
    static func enrollIfEligible(
        at assignedAt: Date,
        in context: ModelContext,
        installationIDProvider: () throws -> UUID = { try RetentionInstallationIdentityStore.appGroup().loadOrCreate() },
        variantSelector: () -> OnboardingExperimentVariant = { Bool.random() ? .control : .guided }
    ) -> ExperimentEnrollmentResult
}
```

Fetch assignment first and return exactly one supported row without calling injected closures only when exactly one matching `RetentionInstallation` also exists.
Treat an assignment without its installation, or an installation-ID mismatch, as `.failed`.
Return `.failed` for duplicate, conflicting, or unsupported assignment rows.
Return `.ineligible` when any installation or quest already exists without an assignment.
Otherwise create `RetentionInstallation` and `ExperimentAssignment` with the same UUID, save once, and remove only those new objects if save fails.
Log no UUID, variant payload, or user content.
Add `ExperimentAssignment.self` to the production and focused-test schemas.

- [ ] **Step 6: Run the Task 1 test command and require PASS**

Expected: assignment, stability, exclusion, failure, snapshot, and migration tests all pass without concurrency warnings.

- [ ] **Step 7: Commit Task 1**

```bash
git add QuestKeeperShared/ExperimentAssignment.swift QuestKeeperShared/ExperimentAssignmentRecorder.swift QuestKeeperShared/QuestModelContainer.swift QuestKeeperTests/ExperimentAssignmentRecorderTests.swift QuestKeeperTests/RetentionPersistenceTests.swift
git diff --cached --check
git commit -m "feat(metrics): persist onboarding experiment assignment"
```

### Task 2: Record Canonical Experiment Events Without Changing Core Metrics

**Files:**

- Modify: `QuestKeeperShared/RetentionEvent.swift:4-9`
- Modify: `QuestKeeperShared/RetentionEventRecorder.swift:49-112`
- Modify: `QuestKeeperShared/RetentionReport.swift:287-300`
- Modify: `QuestKeeperTests/RetentionEventRecorderTests.swift:34-128`
- Modify: `QuestKeeperTests/RetentionReportTests.swift:70-132`

**Interfaces:**

- Consumes: the existing private recorder and deduplication behavior.
- Produces: `.experimentExposed`, `.questCreationStarted`, `.onboardingDeferred`, and typed recorder entry points.

- [ ] **Step 1: Write failing event and compatibility tests**

Exercise these exact calls twice with identical keys and require `.inserted` then `.duplicate`:

```swift
RetentionEventRecorder.recordExperimentExposed(experimentKey: OnboardingExperiment.key, at: now, in: context)
RetentionEventRecorder.recordQuestCreationStarted(experimentKey: OnboardingExperiment.key, actionID: actionID, at: now, in: context)
RetentionEventRecorder.recordOnboardingDeferred(experimentKey: OnboardingExperiment.key, sessionID: sessionID, at: now, in: context)
```

Require app source and nil quest UUID for all three.
Add them to the existing retention fixture and assert every core metric stays identical with zero new unsupported rows.
Add widget-source and non-nil-quest-ID variants and require unsupported counts.

- [ ] **Step 2: Run focused tests and require the missing-symbol failure**

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,id=7ED9020C-A21E-425F-AF74-C71C40DA0A13' -only-testing:QuestKeeperTests/RetentionEventRecorderTests -only-testing:QuestKeeperTests/RetentionReportTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
```

- [ ] **Step 3: Add three event cases and typed recorders**

```swift
case experimentExposed = "experiment_exposed"
case questCreationStarted = "quest_creation_started"
case onboardingDeferred = "onboarding_deferred"
```

The recorder signatures match Step 1.
Use app source, nil quest UUID, and key components `experimentKey`, `"\(experimentKey):\(actionID)"`, and `"\(experimentKey):\(sessionID)"`.
Extend `isValidCombination` to accept only app/nil-quest combinations for these events.
Do not change any core funnel or retention formula and do not add fields to `RetentionEvent`.

- [ ] **Step 4: Run the Task 2 test command and require PASS**

- [ ] **Step 5: Commit Task 2**

```bash
git add QuestKeeperShared/RetentionEvent.swift QuestKeeperShared/RetentionEventRecorder.swift QuestKeeperShared/RetentionReport.swift QuestKeeperTests/RetentionEventRecorderTests.swift QuestKeeperTests/RetentionReportTests.swift
git diff --cached --check
git commit -m "feat(metrics): record onboarding experiment events"
```

### Task 3: Calculate A Strict Pure Onboarding Experiment Report

**Files:**

- Create: `QuestKeeperShared/OnboardingExperimentReport.swift`
- Create: `QuestKeeperTests/Fixtures/OnboardingExperimentFixture.swift`
- Create: `QuestKeeperTests/OnboardingExperimentReportTests.swift`
- Create: `docs/notes/013-onboarding-experiment-baseline.md`

**Interfaces:**

- Consumes: assignment, installation, and event snapshots plus explicit `asOf`, `Calendar`, and half-open cohort `DateInterval`.
- Produces: `OnboardingExperimentFunnel`, `OnboardingVariantMetrics`, `OnboardingExperimentDataQuality`, and `OnboardingExperimentReport.make(...)`.

- [ ] **Step 1: Write the deterministic fixture and failing report tests**

Create two control and two guided installations with fixed UUIDs and `Asia/Seoul` timestamps.
Use these exact expected funnels:

```swift
static let expectedControlFunnel = OnboardingExperimentFunnel(
    exposed: 2,
    creationStarted: 2,
    firstValue: 1,
    firstCompletion: 1
)
static let expectedGuidedFunnel = OnboardingExperimentFunnel(
    exposed: 2,
    creationStarted: 2,
    firstValue: 2,
    firstCompletion: 1
)
```

Shape timestamps so one control and one guided installation reach first value within two minutes, only guided completes its first quest within two minutes, each variant has one eventual same-quest completion, D1 is `1 / 2` for each, D7 excludes young installations, and one guided installation defers.

Assert:

```swift
#expect(report.control.onboardingCompletionWithinTwoMinutes == RetentionRate(achieved: 1, eligible: 2))
#expect(report.guided.onboardingCompletionWithinTwoMinutes == RetentionRate(achieved: 1, eligible: 2))
#expect(report.control.firstSuccessWithinTwoMinutes == RetentionRate(achieved: 0, eligible: 2))
#expect(report.guided.firstSuccessWithinTwoMinutes == RetentionRate(achieved: 1, eligible: 2))
#expect(report.guidedDeferral == RetentionRate(achieved: 1, eligible: 2))
#expect(report.dataQuality.status == .complete)
```

Add isolated tests for the exact two-minute boundary, immature denominators, D1/D7 exact dates, late-day non-backfill, completion of a different quest, duplicate events, missing exposure, conflicting assignments, unsupported variants/schema versions, exposure before assignment, event/installation mismatch, out-of-cohort assignment exclusion, empty rates, odd/even median durations, deterministic Markdown, and forbidden-content absence.

- [ ] **Step 2: Run report tests and verify missing-type failure**

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,id=7ED9020C-A21E-425F-AF74-C71C40DA0A13' -only-testing:QuestKeeperTests/OnboardingExperimentReportTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
```

- [ ] **Step 3: Define the report value types**

```swift
nonisolated struct OnboardingExperimentFunnel: Codable, Equatable, Sendable {
    let exposed: Int
    let creationStarted: Int
    let firstValue: Int
    let firstCompletion: Int
}

nonisolated struct OnboardingVariantMetrics: Codable, Equatable, Sendable {
    let funnel: OnboardingExperimentFunnel
    let onboardingCompletionWithinTwoMinutes: RetentionRate
    let firstSuccessWithinTwoMinutes: RetentionRate
    let firstQuestCompletion: RetentionRate
    let medianTimeToFirstValueSeconds: Double?
    let d1: RetentionRate
    let d7: RetentionRate
}

nonisolated struct OnboardingExperimentDataQuality: Codable, Equatable, Sendable {
    let status: RetentionDataQualityStatus
    let duplicateAssignmentCount: Int
    let conflictingAssignmentCount: Int
    let missingExposureCount: Int
    let unsupportedCount: Int
    let orderingFailureCount: Int
    let crossInstallationMismatchCount: Int
    let duplicateCountsByEvent: [String: Int]
}

nonisolated struct OnboardingExperimentReport: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1
    let schemaVersion: Int
    let experimentKey: String
    let generatedAt: Date
    let timeZoneIdentifier: String
    let cohort: DateInterval
    let control: OnboardingVariantMetrics
    let guided: OnboardingVariantMetrics
    let guidedDeferral: RetentionRate
    let dataQuality: OnboardingExperimentDataQuality

    static func make(
        assignments: [ExperimentAssignmentSnapshot],
        installations: [RetentionInstallationSnapshot],
        events: [RetentionEventSnapshot],
        asOf: Date,
        calendar: Calendar,
        cohort: DateInterval
    ) -> OnboardingExperimentReport

    func renderMarkdown() -> String
}
```

- [ ] **Step 4: Implement canonicalization and metrics in a fixed order**

Filter supported AND-34 assignments into the half-open cohort, group by installation, and exclude duplicate/conflicting groups.
Require one supported matching installation.
Validate event schema, field combination, installation, measurement start, and `asOf` before deduplicating by key with occurrence time and UUID tie-breakers.
For each valid assignment, find first exposure, first later creation start, first later quest creation, same-quest completion, and exact-day activations.
Include a two-minute denominator only when `exposure + 120 <= asOf` and include its numerator only when the target event is at or before that boundary.
Calculate median by sorting successful exposure-to-creation durations and averaging the middle pair for an even count.
Require the complete target local day before D1/D7 eligibility.
Return partial quality for the named invalid cases without parsing deduplication keys or inferring rows.

- [ ] **Step 5: Render and check in the synthetic note**

Render `QuestKeeper Synthetic Onboarding Experiment Baseline`, state that it is synthetic and not real-user evidence, include explicit cohort/time zone, both funnels and all numerator/denominator rates, quality counts, and the Step 2 reproduction command.
Write the output to `docs/notes/013-onboarding-experiment-baseline.md` and assert byte equality from the fixture.

- [ ] **Step 6: Run the Task 3 test command and require PASS**

- [ ] **Step 7: Commit Task 3**

```bash
git add QuestKeeperShared/OnboardingExperimentReport.swift QuestKeeperTests/Fixtures/OnboardingExperimentFixture.swift QuestKeeperTests/OnboardingExperimentReportTests.swift docs/notes/013-onboarding-experiment-baseline.md
git diff --cached --check
git commit -m "feat(metrics): calculate onboarding experiment report"
```

### Task 4: Write The Live Experiment Report On Genuine Activation

**Files:**

- Create: `QuestKeeperShared/OnboardingExperimentStore.swift`
- Create: `QuestKeeperTests/OnboardingExperimentStoreTests.swift`
- Modify: `QuestKeeper/Measurement/RetentionBaselineWriter.swift:5-54`
- Modify: `QuestKeeperTests/RetentionBaselineStoreTests.swift:6-131`

**Interfaces:**

- Consumes: `OnboardingExperimentReport.make`, the existing activation owner, and App Group container resolution.
- Produces: atomic `OnboardingExperimentStore` and activation-driven `onboarding-experiment-v1.json`.

- [ ] **Step 1: Write failing store and writer tests**

```swift
let fileURL = temporaryDirectory().appending(path: OnboardingExperimentStore.fileName)
let store = OnboardingExperimentStore(fileURL: fileURL)
let report = OnboardingExperimentReport.make(
    assignments: OnboardingExperimentFixture.assignments,
    installations: OnboardingExperimentFixture.installations,
    events: OnboardingExperimentFixture.events,
    asOf: OnboardingExperimentFixture.asOf,
    calendar: OnboardingExperimentFixture.calendar,
    cohort: OnboardingExperimentFixture.cohort
)
try store.save(report)
let firstBytes = try Data(contentsOf: fileURL)
try store.save(report)
let secondBytes = try Data(contentsOf: fileURL)
#expect(store.load() == report)
#expect(firstBytes == secondBytes)
```

Cover missing directory creation, missing/corrupt/unsupported JSON returning nil, unavailable App Group throwing, sorted ISO-8601 output, and forbidden-content absence.
Extend the activation writer test with a pre-activation assignment and require one activation, unchanged retention output, and one experiment JSON report.

- [ ] **Step 2: Run focused store tests and verify failure**

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,id=7ED9020C-A21E-425F-AF74-C71C40DA0A13' -only-testing:QuestKeeperTests/OnboardingExperimentStoreTests -only-testing:QuestKeeperTests/RetentionBaselineStoreTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
```

- [ ] **Step 3: Implement the atomic store**

```swift
nonisolated struct OnboardingExperimentStore: Sendable {
    static let fileName = "onboarding-experiment-v1.json"
    init(appGroupIdentifier: String = WidgetDungeonSnapshotStore.appGroupIdentifier, fileManager: FileManager = .default)
    init(fileURL: URL?, fileManager: FileManager = .default)
    func load() -> OnboardingExperimentReport?
    func save(_ report: OnboardingExperimentReport) throws
}
```

Reuse `JSONEncoder.retentionBaseline` and `JSONDecoder.retentionBaseline`, save with `.atomic`, and accept only the current report schema.

- [ ] **Step 4: Extend the activation writer**

Inject `onboardingStore` beside the existing store.
After activation is recorded and saved, fetch assignments, installations, and events; always write the core report first.
If supported assignments exist, use earliest assignment as live exploratory cohort start and explicit activation `now` as the current half-open cohort end, then write the independent experiment report.
This changing end is an as-of snapshot, not enrollment closure or win evidence.
Write no experiment file when assignments are absent, and never undo product events on report failure.

- [ ] **Step 5: Run the Task 4 test command and require PASS**

- [ ] **Step 6: Commit Task 4**

```bash
git add QuestKeeperShared/OnboardingExperimentStore.swift QuestKeeper/Measurement/RetentionBaselineWriter.swift QuestKeeperTests/OnboardingExperimentStoreTests.swift QuestKeeperTests/RetentionBaselineStoreTests.swift
git diff --cached --check
git commit -m "feat(metrics): write live onboarding experiment report"
```

### Task 5: Derive Guided Re-entry And Provide An Editable Template

**Files:**

- Create: `QuestKeeper/Onboarding/OnboardingFlowState.swift`
- Create: `QuestKeeperTests/OnboardingFlowStateTests.swift`
- Modify: `QuestKeeper/Views/QuestEditor.swift:10-110`

**Interfaces:**

- Consumes: assignment, canonical events, pending quest IDs, process-local deferral, and measurement availability.
- Produces: `OnboardingFlowPresentation`, `OnboardingFlowState.make(...)`, and `QuestEditorDraft.guided(at:)`.

- [ ] **Step 1: Write failing transition and draft tests**

```swift
#expect(makeState(events: [], pending: [], deferred: false) == .guidedOffer)
#expect(makeState(events: [], pending: [], deferred: true) == .standard)
#expect(makeState(events: [exposure, creation], pending: [questID], deferred: false) == .guidedCompletion(questID))
#expect(makeState(events: [exposure, creation, completion], pending: [], deferred: false) == .finished)
#expect(makeState(events: [exposure, creation], pending: [], deferred: false) == .standard)

let draft = QuestEditorDraft.guided(at: now)
#expect(draft.title == "물 한 잔 마시기")
#expect(draft.deadline == now.addingTimeInterval(10 * 60))
#expect(draft.importance == .low)
```

Require control, missing/unsupported assignment, unavailable measurement, and events before exposure to produce `.standard` without synthetic progress.

- [ ] **Step 2: Run state tests and verify missing-type failure**

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,id=7ED9020C-A21E-425F-AF74-C71C40DA0A13' -only-testing:QuestKeeperTests/OnboardingFlowStateTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
```

- [ ] **Step 3: Implement the pure state contract**

```swift
nonisolated enum OnboardingFlowPresentation: Equatable, Sendable {
    case standard
    case guidedOffer
    case guidedCompletion(UUID)
    case finished
}

nonisolated enum OnboardingFlowState {
    static func make(
        assignment: ExperimentAssignmentSnapshot?,
        events: [RetentionEventSnapshot],
        pendingQuestIDs: Set<UUID>,
        deferredThisRun: Bool,
        measurementAvailable: Bool
    ) -> OnboardingFlowPresentation
}
```

Return `.standard` unless measurement is available and the assignment is supported guided AND-34.
Use canonical events at or after first exposure.
No creation becomes guided offer unless deferred; same-quest completion becomes finished; an existing pending first quest becomes guided completion; a deleted/absent first quest becomes standard and never triggers another generated quest.

- [ ] **Step 4: Add the editable draft without changing save ownership**

```swift
nonisolated struct QuestEditorDraft: Equatable, Sendable {
    let title: String
    let deadline: Date
    let importance: Importance

    static func guided(at now: Date) -> QuestEditorDraft {
        QuestEditorDraft(title: "물 한 잔 마시기", deadline: now.addingTimeInterval(10 * 60), importance: .low)
    }
}
```

Add `draft: QuestEditorDraft? = nil` to `QuestEditor.init`.
New quests use draft values when supplied and preserve blank-title, one-hour, medium defaults otherwise.
Existing quest edits ignore the draft.
Keep `recordQuestCreated` in the existing new-quest save branch.

- [ ] **Step 5: Run Task 5 tests plus existing quest-action tests**

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,id=7ED9020C-A21E-425F-AF74-C71C40DA0A13' -only-testing:QuestKeeperTests/OnboardingFlowStateTests -only-testing:QuestKeeperTests/QuestActionsTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
```

Expected: PASS with default create/edit and canonical save behavior intact.

- [ ] **Step 6: Commit Task 5**

```bash
git add QuestKeeper/Onboarding/OnboardingFlowState.swift QuestKeeper/Views/QuestEditor.swift QuestKeeperTests/OnboardingFlowStateTests.swift
git diff --cached --check
git commit -m "feat(onboarding): derive guided first-value state"
```

### Task 6: Wire Assignment, Guided UI, Accessibility, And Events

**Files:**

- Modify: `QuestKeeper/QuestKeeperApp.swift:12-104`
- Modify: `QuestKeeper/ContentView.swift:12-213`
- Modify: `QuestKeeper/Views/HomeDungeonBoardView.swift:3-125`
- Modify: `QuestKeeper/Views/QuestListSections.swift:11-49`
- Modify: `QuestKeeper/Views/QuestRow.swift:12-72`
- Modify: `QuestKeeperTests/QuestKeeperAppTests.swift:12-40`

**Interfaces:**

- Consumes: enrollment result, recorder methods, flow state, editor draft, and existing callbacks.
- Produces: pre-UI assignment and exposure resolution, instrumented create/defer actions, approved guided card, and completion guidance.

- [ ] **Step 1: Write failing debug-override and app-state tests**

```swift
#expect(onboardingVariantOverride(arguments: ["QuestKeeper", "-onboardingVariant", "control"]) == .control)
#expect(onboardingVariantOverride(arguments: ["QuestKeeper", "-onboardingVariant", "guided"]) == .guided)
#expect(onboardingVariantOverride(arguments: ["QuestKeeper", "-onboardingVariant", "unknown"]) == nil)
#expect(onboardingVariantOverride(arguments: ["QuestKeeper"]) == nil)
```

Keep the activation-gate assertions unchanged and require `QuestKeeperApp` to own stable widget writer, onboarding session UUID, and process-local deferral state.

- [ ] **Step 2: Run app and state tests and verify failure**

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,id=7ED9020C-A21E-425F-AF74-C71C40DA0A13' -only-testing:QuestKeeperTests/QuestKeeperAppTests -only-testing:QuestKeeperTests/OnboardingFlowStateTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
```

- [ ] **Step 3: Resolve assignment before the root view**

In `QuestKeeperApp.init`, create the model container once, enroll synchronously on its main context, and retain the snapshot before constructing `ContentView`.
Under `#if DEBUG`, force only a new eligible store's selector with:

```swift
nonisolated func onboardingVariantOverride(arguments: [String]) -> OnboardingExperimentVariant? {
    guard let flag = arguments.firstIndex(of: "-onboardingVariant"), arguments.indices.contains(flag + 1) else { return nil }
    return OnboardingExperimentVariant(rawValue: arguments[flag + 1])
}
```

Never overwrite an existing assignment.
For an enrolled or restored assignment, call `recordExperimentExposed` immediately before constructing the root view and treat `.inserted` or `.duplicate` as measurement available.
Treat `.failed` as unavailable and pass no active assignment to the root view, preventing a visible control-to-guided switch later in the same process.
This pre-display call is the canonical first-use exposure boundary and its timestamp starts the two-minute clock.
Add app-level `@State` for deferral and one per-process session UUID, then pass assignment, measurement availability, binding, and session ID into `ContentView`.

- [ ] **Step 4: Record every first-use create action and derive persisted progress**

Add a retention-event query to `ContentView` and derive presentation from the pre-resolved assignment, measurement availability, canonical events, pending quest IDs, and deferral binding.
Before any new-quest route, record creation start with a fresh action UUID.
Use one helper for header add, control empty add, guided manual, and guided template so no entry skips instrumentation.

Carry a draft in the route:

```swift
case create(QuestEditorDraft?)
```

Guided primary uses `.guided(at: .now)`; every other create path uses nil.
Edit and notification routes emit no creation-start event.
Deferral records with the process session UUID and sets the binding even on recorder failure.

- [ ] **Step 5: Render the approved guided card**

```swift
VStack(spacing: 12) {
    Text("첫 승리를 시작해볼까요?")
    Text("2분 안에 끝낼 수 있는 작은 전투부터 시작하세요.")
    Button("2분 전투 시작", action: onStartTemplate)
    Button("직접 만들기", action: onCreateManually)
    Button("나중에", action: onDefer)
}
```

Match the existing pixel card, palette, type, and button style.
Keep `EmptyDungeonState` visually unchanged for control and unassigned flows.
Do not add a countdown, auto-transition, new asset, or notification prompt.
Preserve VoiceOver order as shown, platform touch targets, vertical Dynamic Type expansion, and Reduced Motion independence.

- [ ] **Step 6: Add completion guidance only to the first quest**

Pass `guidedQuestID: UUID?` through `QuestListSections` to the matching row.
Add `showsOnboardingCompletionGuidance: Bool = false` to `QuestRow` and render:

```swift
Text("완료하면 첫 승리를 얻어요")
    .font(.caption.weight(.semibold))
    .foregroundStyle(DungeonPalette.hero)
    .fixedSize(horizontal: false, vertical: true)
```

Use the same sentence as an accessibility hint without replacing the existing named completion action.
Do not change swipe, battle timing, edit, delete, or completion mutation behavior.

- [ ] **Step 7: Run the Task 6 focused test command and require PASS**

- [ ] **Step 8: Build the app once**

```bash
xcodebuild build -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,id=7ED9020C-A21E-425F-AF74-C71C40DA0A13' -jobs 2
```

Expected: `** BUILD SUCCEEDED **` with no new warning in changed files.

- [ ] **Step 9: Commit Task 6**

```bash
git add QuestKeeper/QuestKeeperApp.swift QuestKeeper/ContentView.swift QuestKeeper/Views/HomeDungeonBoardView.swift QuestKeeper/Views/QuestListSections.swift QuestKeeper/Views/QuestRow.swift QuestKeeperTests/QuestKeeperAppTests.swift
git diff --cached --check
git commit -m "feat(onboarding): guide the first quest flow"
```

### Task 7: Verify Both Variants, Accessibility, Persistence, And Reports

**Files:**

- Create: `docs/notes/013-onboarding-experiment-verification.md`
- Modify only for a task-introduced defect: files already listed in Tasks 1-6 and their direct tests

**Interfaces:**

- Consumes: the complete feature at one exact commit SHA.
- Produces: green tests/builds, observed control/guided behavior, privacy-safe JSON evidence, and a Linear progress comment without Done transition.

- [ ] **Step 1: Run the complete unit target once**

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,id=7ED9020C-A21E-425F-AF74-C71C40DA0A13' -only-testing:QuestKeeperTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
```

Expected: every `QuestKeeperTests` suite passes.
Record exact test and suite counts only from complete output or the result bundle.

- [ ] **Step 2: Build app and widget sequentially**

```bash
xcodebuild build -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,id=7ED9020C-A21E-425F-AF74-C71C40DA0A13' -jobs 2
xcodebuild build -project QuestKeeper.xcodeproj -scheme QuestKeeperWidget -destination 'platform=iOS Simulator,id=7ED9020C-A21E-425F-AF74-C71C40DA0A13' -jobs 2
```

Expected: both finish with `** BUILD SUCCEEDED **`; never run them concurrently.

- [ ] **Step 3: QA a clean forced control installation**

Invoke `build-ios-apps:ios-debugger-agent` for build/install/launch and `build-ios-apps:ios-simulator-browser` plus `omo:visual-qa` for observable UI verification.
Uninstall first, reinstall the verified build, and launch with `-onboardingVariant control`.

Verify the existing empty dungeon is visually unchanged, no guided copy appears, header and empty-state actions open the blank editor, save and completion behave as before, background/foreground writes the experiment JSON, the report identifies control, and typed quest titles occur in neither JSON file.

- [ ] **Step 4: QA clean guided installations and interruption recovery**

Uninstall and reinstall before each independent scenario, then launch with `-onboardingVariant guided`.

Verify:

1. Guided copy and VoiceOver order match the approved sequence.
2. Primary action opens editable `물 한 잔 마시기`, ten-minute deadline, and low importance.
3. Cancel before save returns to the guided card.
4. `나중에` hides for this process, survives background/foreground, and resets on a new process launch.
5. Save shows `완료하면 첫 승리를 얻어요`; terminate and relaunch before completion restores it.
6. Complete removes guidance and records completion for the first quest UUID.
7. Delete before completion returns to the ordinary empty state without another generated quest.
8. Accessibility Dynamic Type does not truncate actions or require horizontal scrolling.
9. Reduced Motion preserves all instructions and actions.
10. JSON contains the guided assignment and approved event names but no prefilled or edited title.

- [ ] **Step 5: Inspect both App Group reports**

```bash
group_path=$(xcrun simctl get_app_container 7ED9020C-A21E-425F-AF74-C71C40DA0A13 kr.donminzzi.QuestKeeper group.kr.donminzzi.QuestKeeper)
jq . "$group_path/retention-baseline-v1.json"
jq . "$group_path/onboarding-experiment-v1.json"
```

Require unchanged core semantics, correct forced variant, complete quality for valid flows, and exclusion of immature two-minute/D1/D7 denominators.
Search both files for every typed title and require zero matches.

- [ ] **Step 6: Write exact verification evidence**

Create `docs/notes/013-onboarding-experiment-verification.md` containing the full verified SHA, simulator model/identifier/OS, exact test and suite counts, app/widget build results, both variant observations, interruption and accessibility checks, JSON filenames/status, and an explicit statement that fixture and single-device results are not population evidence.
Mark any unverified criterion or OS-controlled limitation explicitly.

- [ ] **Step 7: Commit only the verification note**

```bash
git add docs/notes/013-onboarding-experiment-verification.md
git diff --cached --check
git commit -m "docs(metrics): record onboarding experiment verification"
```

- [ ] **Step 8: Run lightweight final checks after the docs-only commit**

```bash
cspell docs/specs/013-first-value-onboarding-experiment.md docs/plans/2026-07-21-first-value-onboarding-experiment.md docs/notes/013-onboarding-experiment-baseline.md docs/notes/013-onboarding-experiment-verification.md
git diff --check origin/main...HEAD
git status --short --branch
```

Expected: zero spelling issues, clean diff check, and clean worktree.
Do not repeat heavy tests/builds when only Markdown changed after their green run.

- [ ] **Step 9: Update Linear without closing the issue**

Comment on AND-34 with final SHA, exact test/suite counts, both build results, baseline path, live JSON filename, both manual variant results, and the remaining need for a deliberately closed live cohort plus independent eligible installations.
Keep AND-34 In Progress until a PR is separately requested, attached, reviewed, and merged.
Do not push, create a PR, or merge without a separate user request.

---

## Final Verification Checklist

- [ ] AND-34 is In Progress and remains assigned to Andrew Yu.
- [ ] One stable assignment exists per eligible installation and existing installations are not backfilled.
- [ ] Control remains visually unchanged and guided behavior uses every approved Korean string.
- [ ] Exposure, creation start, deferral, creation, and same-quest completion are canonical and privacy-safe.
- [ ] Core retention formulas remain unchanged and accept the new valid event names.
- [ ] Experiment metrics use explicit cohort, two-minute, D1, and D7 right-censoring.
- [ ] Conflicts, duplicates, unsupported values, and invalid order produce partial quality without repair.
- [ ] `Quest` contains no experiment or onboarding field.
- [ ] Synthetic output is byte-stable and labeled non-population evidence.
- [ ] Live output is atomic, local-only, and excludes quest titles.
- [ ] Full unit tests pass with parallel testing disabled.
- [ ] App and widget builds succeed sequentially.
- [ ] Forced control and guided flows pass manual simulator and visual QA.
- [ ] Interruption, VoiceOver, accessibility Dynamic Type, and Reduced Motion are observed.
- [ ] Verification evidence records the exact SHA and non-truncated counts.
- [ ] Worktree is clean and no PR or merge occurred without a separate request.
