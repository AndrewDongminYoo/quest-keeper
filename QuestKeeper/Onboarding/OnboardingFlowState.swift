import Foundation

nonisolated enum OnboardingFlowPresentation: Equatable, Sendable {
    case standard
    case guidedOffer
    case guidedCompletion(UUID)
    case finished

    /// Whether the guided first-quest flow is still live — the offer *and* the completion that
    /// follows it, because the experiment measures completion, not creation. Surfaces that must not
    /// compete with the guided template gate on this rather than on one case: `.guidedOffer` alone
    /// leaves the whole completion phase unguarded, and the enum grows.
    var isGuidingFirstQuest: Bool {
        switch self {
        case .guidedOffer, .guidedCompletion: true
        case .standard, .finished: false
        }
    }
}

nonisolated enum OnboardingFlowState {
    /// Whether `make` can return anything other than `.standard`. Callers gate on this before
    /// materialising the event history — `make` re-checks it, so the two can never disagree.
    static func isGuidedFlowActive(
        assignment: ExperimentAssignmentSnapshot?,
        measurementAvailable: Bool
    ) -> Bool {
        guard measurementAvailable, let assignment else { return false }
        return assignment.schemaVersion == ExperimentAssignment.currentSchemaVersion
            && assignment.experimentKey == OnboardingExperiment.key
            && assignment.variant == .guided
    }

    static func make(
        assignment: ExperimentAssignmentSnapshot?,
        events: [RetentionEventSnapshot],
        pendingQuestIDs: Set<UUID>,
        hasExistingQuests: Bool,
        deferredThisRun: Bool,
        measurementAvailable: Bool
    ) -> OnboardingFlowPresentation {
        guard isGuidedFlowActive(
            assignment: assignment,
            measurementAvailable: measurementAvailable
        ), let assignment else {
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
                && ($0.name?.isExperimentSpecific != true
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
        case .questCreated:
            return (source == .app || source == .shortcut) && event.questID != nil
        case .questRetried:
            return source == .app && event.questID != nil
        case .questCompleted:
            return (source == .app || source == .widget) && event.questID != nil
        case .reengagementPermissionRequested,
             .reengagementPermissionGranted,
             .reengagementPermissionDenied,
             .reengagementReminderEnabled,
             .reengagementReminderDisabled:
            return source == .app && event.questID == nil
        case .reengagementNotificationOpened, .reengagementNotificationCompleted:
            return source == .app && event.questID != nil
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

    static func guided(at now: Date, locale: Locale = .current) -> QuestEditorDraft {
        QuestEditorDraft(
            title: AppStrings.resolve(AppStrings.onboardingGuidedQuestTitle, locale: locale),
            deadline: now.addingTimeInterval(10 * 60),
            importance: .low
        )
    }
}
