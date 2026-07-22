import Foundation
import Testing
@testable import QuestKeeper

struct OnboardingFlowStateTests {
    private let installationID = UUID(uuidString: "00000000-0000-0000-0000-000000000034")!
    private let questID = UUID(uuidString: "00000000-0000-0000-0000-000000000134")!
    private let otherQuestID = UUID(uuidString: "00000000-0000-0000-0000-000000000234")!
    private let assignedAt = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test("guided assignment offers the first quest until deferred")
    func guidedOfferAndDeferral() {
        #expect(makeState(events: [], pending: [], deferred: false) == .guidedOffer)
        #expect(makeState(events: [], pending: [], deferred: true) == .standard)
    }

    @Test("saved first quest restores completion guidance")
    func pendingFirstQuest() {
        #expect(makeState(
            events: [exposure(), creation()],
            pending: [questID],
            deferred: false
        ) == .guidedCompletion(questID))
    }

    @Test("same-quest completion finishes guided onboarding")
    func completedFirstQuest() {
        #expect(makeState(
            events: [exposure(), creation(), completion(questID)],
            pending: [],
            deferred: false
        ) == .finished)
    }

    @Test("another quest completion does not finish onboarding")
    func otherQuestCompletion() {
        #expect(makeState(
            events: [exposure(), creation(), completion(otherQuestID)],
            pending: [questID],
            deferred: false
        ) == .guidedCompletion(questID))
    }

    @Test("deleted first quest returns to standard without generating another")
    func deletedFirstQuest() {
        #expect(makeState(
            events: [exposure(), creation()],
            pending: [],
            deferred: false
        ) == .standard)
    }

    @Test("editor cancellation leaves the guided offer available")
    func cancelledEditor() {
        #expect(makeState(
            events: [exposure(), creationStarted()],
            pending: [],
            deferred: false
        ) == .guidedOffer)
    }

    @Test("a pending quest stays visible when its creation event is missing")
    func pendingQuestWithoutCreationEvent() {
        #expect(makeState(
            events: [exposure()],
            pending: [questID],
            deferred: false
        ) == .standard)
    }

    @Test("an expired quest stays visible when its creation event is missing")
    func expiredQuestWithoutCreationEvent() {
        #expect(makeState(
            events: [exposure()],
            pending: [],
            hasExistingQuests: true,
            deferred: false
        ) == .standard)
    }

    @Test("creation start is recorded only before first value")
    func creationStartGate() {
        #expect(OnboardingFlowState.shouldRecordCreationStarted(
            assignment: assignment(variant: .control),
            events: [exposure()],
            hasExistingQuests: false,
            measurementAvailable: true
        ))
        #expect(OnboardingFlowState.shouldRecordCreationStarted(
            assignment: assignment(),
            events: [exposure(), creationStarted()],
            hasExistingQuests: false,
            measurementAvailable: true
        ))
        #expect(!OnboardingFlowState.shouldRecordCreationStarted(
            assignment: assignment(),
            events: [exposure(), creation()],
            hasExistingQuests: true,
            measurementAvailable: true
        ))
        #expect(!OnboardingFlowState.shouldRecordCreationStarted(
            assignment: assignment(),
            events: [exposure()],
            hasExistingQuests: false,
            measurementAvailable: false
        ))
    }

    @Test("control unsupported missing and unavailable measurement stay standard")
    func unsupportedInputs() {
        let control = assignment(variant: .control)
        let unsupported = ExperimentAssignmentSnapshot(
            schemaVersion: 2,
            experimentKey: OnboardingExperiment.key,
            installationID: installationID,
            variantRawValue: OnboardingExperimentVariant.guided.rawValue,
            assignedAt: assignedAt
        )

        #expect(OnboardingFlowState.make(
            assignment: control,
            events: [],
            pendingQuestIDs: [],
            hasExistingQuests: false,
            deferredThisRun: false,
            measurementAvailable: true
        ) == .standard)
        #expect(OnboardingFlowState.make(
            assignment: unsupported,
            events: [],
            pendingQuestIDs: [],
            hasExistingQuests: false,
            deferredThisRun: false,
            measurementAvailable: true
        ) == .standard)
        #expect(OnboardingFlowState.make(
            assignment: nil,
            events: [],
            pendingQuestIDs: [],
            hasExistingQuests: false,
            deferredThisRun: false,
            measurementAvailable: true
        ) == .standard)
        #expect(OnboardingFlowState.make(
            assignment: assignment(),
            events: [],
            pendingQuestIDs: [],
            hasExistingQuests: false,
            deferredThisRun: false,
            measurementAvailable: false
        ) == .standard)
    }

    @Test("events before exposure do not create synthetic progress")
    func preExposureEvents() {
        let earlyCreation = event(
            id: 20,
            name: .questCreated,
            at: assignedAt.addingTimeInterval(1),
            questID: questID
        )
        let laterExposure = event(
            id: 21,
            name: .experimentExposed,
            at: assignedAt.addingTimeInterval(2)
        )

        #expect(makeState(
            events: [earlyCreation, laterExposure],
            pending: [questID],
            deferred: false
        ) == .standard)
    }

    @Test("guided editor draft is deterministic and editable")
    func guidedDraft() {
        let draft = QuestEditorDraft.guided(at: assignedAt)

        #expect(draft.title == "물 한 잔 마시기")
        #expect(draft.deadline == assignedAt.addingTimeInterval(10 * 60))
        #expect(draft.importance == .low)
    }

    private func makeState(
        events: [RetentionEventSnapshot],
        pending: Set<UUID>,
        hasExistingQuests: Bool? = nil,
        deferred: Bool
    ) -> OnboardingFlowPresentation {
        OnboardingFlowState.make(
            assignment: assignment(),
            events: events,
            pendingQuestIDs: pending,
            hasExistingQuests: hasExistingQuests ?? !pending.isEmpty,
            deferredThisRun: deferred,
            measurementAvailable: true
        )
    }

    private func assignment(
        variant: OnboardingExperimentVariant = .guided
    ) -> ExperimentAssignmentSnapshot {
        ExperimentAssignmentSnapshot(
            schemaVersion: 1,
            experimentKey: OnboardingExperiment.key,
            installationID: installationID,
            variantRawValue: variant.rawValue,
            assignedAt: assignedAt
        )
    }

    private func exposure() -> RetentionEventSnapshot {
        event(id: 1, name: .experimentExposed, at: assignedAt)
    }

    private func creationStarted() -> RetentionEventSnapshot {
        event(id: 2, name: .questCreationStarted, at: assignedAt.addingTimeInterval(1))
    }

    private func creation() -> RetentionEventSnapshot {
        event(id: 3, name: .questCreated, at: assignedAt.addingTimeInterval(2), questID: questID)
    }

    private func completion(_ completedQuestID: UUID) -> RetentionEventSnapshot {
        event(
            id: completedQuestID == questID ? 4 : 5,
            name: .questCompleted,
            at: assignedAt.addingTimeInterval(3),
            questID: completedQuestID
        )
    }

    private func event(
        id: Int,
        name: RetentionEventName,
        at occurredAt: Date,
        questID: UUID? = nil
    ) -> RetentionEventSnapshot {
        let component: String
        switch name {
        case .experimentExposed:
            component = OnboardingExperiment.key
        case .questCreationStarted, .onboardingDeferred:
            component = "\(OnboardingExperiment.key):\(id)"
        default:
            component = String(id)
        }
        return RetentionEventSnapshot(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0001-%012d", id))!,
            schemaVersion: 1,
            nameRawValue: name.rawValue,
            installationID: installationID,
            occurredAt: occurredAt,
            sourceRawValue: RetentionEventSource.app.rawValue,
            questID: questID,
            deduplicationKey: "\(name.rawValue):\(installationID.uuidString):\(component)"
        )
    }
}
