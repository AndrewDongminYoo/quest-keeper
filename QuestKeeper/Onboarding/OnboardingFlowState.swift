import Foundation

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
        hasExistingQuests: Bool,
        deferredThisRun: Bool,
        measurementAvailable: Bool
    ) -> OnboardingFlowPresentation {
        guard measurementAvailable,
              let assignment,
              assignment.schemaVersion == ExperimentAssignment.currentSchemaVersion,
              assignment.experimentKey == OnboardingExperiment.key,
              assignment.variant == .guided else {
            return .standard
        }

        let canonicalEvents = canonicalEvents(for: assignment, events: events)

        guard !canonicalEvents.isEmpty else {
            return deferredThisRun ? .standard : .guidedOffer
        }
        guard let exposureIndex = canonicalEvents.firstIndex(where: {
            $0.name == .experimentExposed
        }) else {
            return .standard
        }

        let preExposureProgress = canonicalEvents[..<exposureIndex].contains {
            $0.name == .questCreationStarted
                || $0.name == .questCreated
                || $0.name == .questCompleted
                || $0.name == .onboardingDeferred
        }
        guard !preExposureProgress else { return .standard }

        let laterEvents = canonicalEvents.dropFirst(exposureIndex + 1)
        guard let firstCreation = laterEvents.first(where: { $0.name == .questCreated }),
              let firstQuestID = firstCreation.questID else {
            if hasExistingQuests { return .standard }
            return deferredThisRun ? .standard : .guidedOffer
        }

        if laterEvents.contains(where: {
            $0.name == .questCompleted
                && $0.questID == firstQuestID
                && eventOrdering(firstCreation, $0)
        }) {
            return .finished
        }
        if pendingQuestIDs.contains(firstQuestID) {
            return .guidedCompletion(firstQuestID)
        }
        return .standard
    }

    static func shouldRecordCreationStarted(
        assignment: ExperimentAssignmentSnapshot?,
        events: [RetentionEventSnapshot],
        hasExistingQuests: Bool,
        measurementAvailable: Bool
    ) -> Bool {
        guard !hasExistingQuests,
              measurementAvailable,
              let assignment,
              assignment.schemaVersion == ExperimentAssignment.currentSchemaVersion,
              assignment.experimentKey == OnboardingExperiment.key,
              assignment.variant != nil else {
            return false
        }
        let events = canonicalEvents(for: assignment, events: events)
        guard let exposureIndex = events.firstIndex(where: { $0.name == .experimentExposed }) else {
            return false
        }
        let laterEvents = events.dropFirst(exposureIndex + 1)
        return !laterEvents.contains { $0.name == .questCreated }
    }

    private static func canonicalEvents(
        for assignment: ExperimentAssignmentSnapshot,
        events: [RetentionEventSnapshot]
    ) -> [RetentionEventSnapshot] {
        let validEvents = events.filter {
            $0.installationID == assignment.installationID
                && $0.schemaVersion == RetentionEvent.currentSchemaVersion
                && $0.occurredAt >= assignment.assignedAt
                && validCombination($0)
                && (!$0.name!.isExperimentSpecific
                    || $0.experimentKeyComponent == assignment.experimentKey)
        }
        return Dictionary(grouping: validEvents, by: \.deduplicationKey)
            .compactMap { _, rows in rows.sorted(by: eventOrdering).first }
            .sorted(by: eventOrdering)
    }

    private static func validCombination(_ event: RetentionEventSnapshot) -> Bool {
        guard let name = event.name, let source = event.source else { return false }
        switch name {
        case .appActivated, .experimentExposed, .questCreationStarted, .onboardingDeferred:
            return source == .app && event.questID == nil
        case .questCreated, .questRetried:
            return source == .app && event.questID != nil
        case .questCompleted:
            return event.questID != nil
        }
    }

    private static func eventOrdering(
        _ lhs: RetentionEventSnapshot,
        _ rhs: RetentionEventSnapshot
    ) -> Bool {
        if lhs.occurredAt != rhs.occurredAt { return lhs.occurredAt < rhs.occurredAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

nonisolated struct QuestEditorDraft: Equatable, Sendable {
    let title: String
    let deadline: Date
    let importance: Importance

    static func guided(at now: Date) -> QuestEditorDraft {
        QuestEditorDraft(
            title: "물 한 잔 마시기",
            deadline: now.addingTimeInterval(10 * 60),
            importance: .low
        )
    }
}
