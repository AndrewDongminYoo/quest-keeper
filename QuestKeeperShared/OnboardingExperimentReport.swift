import Foundation

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
    ) -> OnboardingExperimentReport {
        var quality = QualityAccumulator()
        let matchingAssignments = assignments.filter { $0.experimentKey == OnboardingExperiment.key }
        let allExperimentInstallationIDs = Set(matchingAssignments.map(\.installationID))
        let cohortAssignments = matchingAssignments.filter {
            $0.assignedAt >= cohort.start && $0.assignedAt < cohort.end
        }

        var supportedAssignments: [ExperimentAssignmentSnapshot] = []
        for rows in Dictionary(grouping: cohortAssignments, by: \.installationID).values {
            let supportedRows = rows.filter {
                $0.schemaVersion == ExperimentAssignment.currentSchemaVersion && $0.variant != nil
            }
            quality.unsupportedCount += rows.count - supportedRows.count
            guard rows.count == 1 else {
                if rows.dropFirst().allSatisfy({ $0 == rows[0] }) {
                    quality.duplicateAssignmentCount += rows.count - 1
                } else {
                    quality.conflictingAssignmentCount += 1
                }
                continue
            }
            guard supportedRows.count == 1 else { continue }
            supportedAssignments.append(supportedRows[0])
        }

        let installationsByID = Dictionary(grouping: installations, by: \.installationID)
        var eligibleAssignments: [ExperimentAssignmentSnapshot] = []
        var eligibleInstallations: [UUID: RetentionInstallationSnapshot] = [:]
        for assignment in supportedAssignments {
            let rows = installationsByID[assignment.installationID] ?? []
            let supportedRows = rows.filter {
                $0.schemaVersion == RetentionInstallation.currentSchemaVersion
            }
            quality.unsupportedCount += rows.count - supportedRows.count
            guard supportedRows.count == 1,
                  supportedRows[0].measurementStartedAt <= assignment.assignedAt else {
                quality.crossInstallationMismatchCount += 1
                continue
            }
            eligibleAssignments.append(assignment)
            eligibleInstallations[assignment.installationID] = supportedRows[0]
        }

        let eligibleAssignmentsByID = Dictionary(
            uniqueKeysWithValues: eligibleAssignments.map { ($0.installationID, $0) }
        )
        let knownInstallationIDs = Set(installations.map(\.installationID))
        var contaminatedInstallationIDs: Set<UUID> = []
        var validEvents: [RetentionEventSnapshot] = []
        for event in events {
            let eventExperimentKey = event.experimentKeyComponent
            if event.name?.isExperimentSpecific == true {
                guard let eventExperimentKey else {
                    if eligibleAssignmentsByID[event.installationID] != nil {
                        quality.unsupportedCount += 1
                        contaminatedInstallationIDs.insert(event.installationID)
                    }
                    continue
                }
                guard eventExperimentKey == OnboardingExperiment.key else { continue }
            }
            guard allExperimentInstallationIDs.contains(event.installationID) else {
                if eventExperimentKey == OnboardingExperiment.key
                    || !knownInstallationIDs.contains(event.installationID) {
                    quality.crossInstallationMismatchCount += 1
                }
                continue
            }
            guard let assignment = eligibleAssignmentsByID[event.installationID],
                  let installation = eligibleInstallations[event.installationID] else {
                continue
            }
            guard event.schemaVersion == RetentionEvent.currentSchemaVersion,
                  let name = event.name,
                  let source = event.source,
                  validCombination(name: name, source: source, questID: event.questID) else {
                quality.unsupportedCount += 1
                contaminatedInstallationIDs.insert(event.installationID)
                continue
            }
            guard name != .onboardingDeferred || assignment.variant == .guided else {
                quality.unsupportedCount += 1
                contaminatedInstallationIDs.insert(event.installationID)
                continue
            }
            guard event.occurredAt >= installation.measurementStartedAt,
                  event.occurredAt >= assignment.assignedAt else {
                if name.isOnboardingProgress {
                    quality.orderingFailureCount += 1
                    contaminatedInstallationIDs.insert(event.installationID)
                }
                continue
            }
            guard event.occurredAt <= asOf else { continue }
            validEvents.append(event)
        }

        let canonicalEvents = Dictionary(grouping: validEvents, by: \.deduplicationKey)
            .compactMap { _, rows -> RetentionEventSnapshot? in
                let sorted = rows.sorted(by: eventOrdering)
                for duplicate in sorted.dropFirst() {
                    quality.duplicateCountsByEvent[duplicate.nameRawValue, default: 0] += 1
                }
                if sorted.count > 1 {
                    contaminatedInstallationIDs.formUnion(sorted.map(\.installationID))
                }
                return sorted.first
            }
            .sorted(by: eventOrdering)
        let eventsByInstallation = Dictionary(grouping: canonicalEvents, by: \.installationID)

        var control = VariantAccumulator()
        var guided = VariantAccumulator()
        for assignment in eligibleAssignments.sorted(by: assignmentOrdering) {
            guard !contaminatedInstallationIDs.contains(assignment.installationID) else {
                continue
            }
            let assignmentEvents = eventsByInstallation[assignment.installationID] ?? []
            guard let journey = makeJourney(
                assignment: assignment,
                events: assignmentEvents,
                asOf: asOf,
                calendar: calendar,
                quality: &quality
            ) else { continue }
            guard let variant = assignment.variant else { continue }
            switch variant {
            case .control:
                control.add(journey)
            case .guided:
                guided.add(journey)
            }
        }

        let dataQuality = quality.snapshot
        return OnboardingExperimentReport(
            schemaVersion: currentSchemaVersion,
            experimentKey: OnboardingExperiment.key,
            generatedAt: asOf,
            timeZoneIdentifier: calendar.timeZone.identifier,
            cohort: cohort,
            control: control.metrics,
            guided: guided.metrics,
            guidedDeferral: RetentionRate(
                achieved: guided.deferred,
                eligible: guided.exposed
            ),
            dataQuality: dataQuality
        )
    }

    func renderMarkdown() -> String {
        let lines = [
            "# QuestKeeper Synthetic Onboarding Experiment Baseline",
            "",
            "> Synthetic fixture output only. This is not real-user evidence.",
            "",
            "## Cohort",
            "",
            "- Experiment: \(experimentKey).",
            "- Start: \(Self.iso8601(cohort.start)).",
            "- End (exclusive): \(Self.iso8601(cohort.end)).",
            "- As of: \(Self.iso8601(generatedAt)).",
            "- Time zone: \(timeZoneIdentifier).",
            "",
            "## Control",
            "",
            Self.renderVariant(control),
            "",
            "## Guided",
            "",
            Self.renderVariant(guided),
            "- Guided deferral: \(Self.render(guidedDeferral)).",
            "",
            "## Data Quality",
            "",
            "- Status: \(dataQuality.status.rawValue).",
            "- Duplicate assignments: \(dataQuality.duplicateAssignmentCount).",
            "- Conflicting assignments: \(dataQuality.conflictingAssignmentCount).",
            "- Missing exposures: \(dataQuality.missingExposureCount).",
            "- Unsupported rows: \(dataQuality.unsupportedCount).",
            "- Ordering failures: \(dataQuality.orderingFailureCount).",
            "- Cross-installation mismatches: \(dataQuality.crossInstallationMismatchCount).",
            "- Duplicate events: \(dataQuality.duplicateCountsByEvent.values.reduce(0, +)).",
            "",
            "## Reproduce",
            "",
            "```bash",
            "xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,id=CDF2239B-B46C-4A44-A09E-ED656EF7F9EA' -only-testing:QuestKeeperTests/OnboardingExperimentReportTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2",
            "```",
            "",
        ]
        return lines.joined(separator: "\n")
    }

    private static func renderVariant(_ metrics: OnboardingVariantMetrics) -> String {
        [
            "- Funnel: \(metrics.funnel.exposed) exposed -> \(metrics.funnel.creationStarted) creation started -> \(metrics.funnel.firstValue) first value -> \(metrics.funnel.firstCompletion) first completion.",
            "- Onboarding completion within two minutes: \(render(metrics.onboardingCompletionWithinTwoMinutes)).",
            "- First success within two minutes: \(render(metrics.firstSuccessWithinTwoMinutes)).",
            "- First-quest completion: \(render(metrics.firstQuestCompletion)).",
            "- Median time to first value: \(renderDuration(metrics.medianTimeToFirstValueSeconds)).",
            "- D1: \(render(metrics.d1)).",
            "- D7: \(render(metrics.d7)).",
        ].joined(separator: "\n")
    }

    private static func render(_ rate: RetentionRate) -> String {
        guard let value = rate.value else { return "\(rate.achieved) / \(rate.eligible), N/A" }
        let percentage = String(format: "%.1f%%", locale: Locale(identifier: "en_US_POSIX"), value * 100)
        return "\(rate.achieved) / \(rate.eligible), \(percentage)"
    }

    private static func renderDuration(_ value: Double?) -> String {
        guard let value else { return "N/A" }
        return String(format: "%.1f seconds", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private static func iso8601(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}

private nonisolated struct OnboardingJourney {
    let exposed: Bool
    let creationStarted: Bool
    let firstValueAt: Date?
    let firstCompletionAt: Date?
    let twoMinuteWindowMatured: Bool
    let firstValueWithinTwoMinutes: Bool
    let firstSuccessWithinTwoMinutes: Bool
    let returnedD1: Bool
    let d1Eligible: Bool
    let returnedD7: Bool
    let d7Eligible: Bool
    let deferred: Bool
    let timeToFirstValue: TimeInterval?
}

private nonisolated struct VariantAccumulator {
    var exposed = 0
    var creationStarted = 0
    var firstValue = 0
    var firstCompletion = 0
    var matureTwoMinute = 0
    var firstValueWithinTwoMinutes = 0
    var firstSuccessWithinTwoMinutes = 0
    var d1Eligible = 0
    var returnedD1 = 0
    var d7Eligible = 0
    var returnedD7 = 0
    var deferred = 0
    var firstValueDurations: [TimeInterval] = []

    mutating func add(_ journey: OnboardingJourney) {
        exposed += journey.exposed ? 1 : 0
        creationStarted += journey.creationStarted ? 1 : 0
        firstValue += journey.firstValueAt == nil ? 0 : 1
        firstCompletion += journey.firstCompletionAt == nil ? 0 : 1
        matureTwoMinute += journey.twoMinuteWindowMatured ? 1 : 0
        firstValueWithinTwoMinutes += journey.firstValueWithinTwoMinutes ? 1 : 0
        firstSuccessWithinTwoMinutes += journey.firstSuccessWithinTwoMinutes ? 1 : 0
        d1Eligible += journey.d1Eligible ? 1 : 0
        returnedD1 += journey.returnedD1 ? 1 : 0
        d7Eligible += journey.d7Eligible ? 1 : 0
        returnedD7 += journey.returnedD7 ? 1 : 0
        deferred += journey.deferred ? 1 : 0
        if let duration = journey.timeToFirstValue {
            firstValueDurations.append(duration)
        }
    }

    var metrics: OnboardingVariantMetrics {
        OnboardingVariantMetrics(
            funnel: OnboardingExperimentFunnel(
                exposed: exposed,
                creationStarted: creationStarted,
                firstValue: firstValue,
                firstCompletion: firstCompletion
            ),
            onboardingCompletionWithinTwoMinutes: RetentionRate(
                achieved: firstValueWithinTwoMinutes,
                eligible: matureTwoMinute
            ),
            firstSuccessWithinTwoMinutes: RetentionRate(
                achieved: firstSuccessWithinTwoMinutes,
                eligible: matureTwoMinute
            ),
            firstQuestCompletion: RetentionRate(
                achieved: firstCompletion,
                eligible: firstValue
            ),
            medianTimeToFirstValueSeconds: median(firstValueDurations),
            d1: RetentionRate(achieved: returnedD1, eligible: d1Eligible),
            d7: RetentionRate(achieved: returnedD7, eligible: d7Eligible)
        )
    }
}

private nonisolated struct QualityAccumulator {
    var duplicateAssignmentCount = 0
    var conflictingAssignmentCount = 0
    var missingExposureCount = 0
    var unsupportedCount = 0
    var orderingFailureCount = 0
    var crossInstallationMismatchCount = 0
    var duplicateCountsByEvent: [String: Int] = [:]

    var snapshot: OnboardingExperimentDataQuality {
        let partial = duplicateAssignmentCount > 0
            || conflictingAssignmentCount > 0
            || missingExposureCount > 0
            || unsupportedCount > 0
            || orderingFailureCount > 0
            || crossInstallationMismatchCount > 0
            || !duplicateCountsByEvent.isEmpty
        return OnboardingExperimentDataQuality(
            status: partial ? .partial : .complete,
            duplicateAssignmentCount: duplicateAssignmentCount,
            conflictingAssignmentCount: conflictingAssignmentCount,
            missingExposureCount: missingExposureCount,
            unsupportedCount: unsupportedCount,
            orderingFailureCount: orderingFailureCount,
            crossInstallationMismatchCount: crossInstallationMismatchCount,
            duplicateCountsByEvent: duplicateCountsByEvent
        )
    }
}

private nonisolated func makeJourney(
    assignment: ExperimentAssignmentSnapshot,
    events: [RetentionEventSnapshot],
    asOf: Date,
    calendar: Calendar,
    quality: inout QualityAccumulator
) -> OnboardingJourney? {
    let ordered = events.sorted(by: eventOrdering)
    guard let exposureIndex = ordered.firstIndex(where: { $0.name == .experimentExposed }) else {
        quality.missingExposureCount += 1
        return nil
    }

    let exposure = ordered[exposureIndex]
    let eventsBeforeExposure = ordered[..<exposureIndex].filter {
        $0.name?.isOnboardingProgress == true
    }
    quality.orderingFailureCount += eventsBeforeExposure.count
    guard eventsBeforeExposure.isEmpty else { return nil }

    let laterEvents = ordered.dropFirst(exposureIndex + 1)
    let creationStart = laterEvents.first(where: { $0.name == .questCreationStarted })
    let firstCreation = laterEvents.first(where: { $0.name == .questCreated })
    let completions = laterEvents.filter { $0.name == .questCompleted }
    let contradictoryCompletions = completions.filter { completion in
        guard let firstCreation else { return true }
        return completion.questID != firstCreation.questID
            || !eventOrdering(firstCreation, completion)
    }
    quality.orderingFailureCount += contradictoryCompletions.count
    guard contradictoryCompletions.isEmpty else { return nil }
    let firstCompletion = completions.first
    let boundary = exposure.occurredAt.addingTimeInterval(120)
    let d1 = retention(
        dayOffset: 1,
        exposure: exposure.occurredAt,
        events: laterEvents,
        asOf: asOf,
        calendar: calendar
    )
    let d7 = retention(
        dayOffset: 7,
        exposure: exposure.occurredAt,
        events: laterEvents,
        asOf: asOf,
        calendar: calendar
    )

    return OnboardingJourney(
        exposed: true,
        creationStarted: creationStart != nil,
        firstValueAt: firstCreation?.occurredAt,
        firstCompletionAt: firstCompletion?.occurredAt,
        twoMinuteWindowMatured: boundary <= asOf,
        firstValueWithinTwoMinutes: firstCreation?.occurredAt ?? .distantFuture <= boundary,
        firstSuccessWithinTwoMinutes: firstCompletion?.occurredAt ?? .distantFuture <= boundary,
        returnedD1: d1.returned,
        d1Eligible: d1.eligible,
        returnedD7: d7.returned,
        d7Eligible: d7.eligible,
        deferred: laterEvents.contains { $0.name == .onboardingDeferred },
        timeToFirstValue: firstCreation.map { $0.occurredAt.timeIntervalSince(exposure.occurredAt) }
    )
}

private nonisolated func retention(
    dayOffset: Int,
    exposure: Date,
    events: ArraySlice<RetentionEventSnapshot>,
    asOf: Date,
    calendar: Calendar
) -> (eligible: Bool, returned: Bool) {
    let cohortDay = calendar.startOfDay(for: exposure)
    guard let targetStart = calendar.date(byAdding: .day, value: dayOffset, to: cohortDay),
          let targetEnd = calendar.date(byAdding: .day, value: 1, to: targetStart),
          targetEnd <= asOf else {
        return (false, false)
    }
    let returned = events.contains {
        $0.name == .appActivated && $0.occurredAt >= targetStart && $0.occurredAt < targetEnd
    }
    return (true, returned)
}

private nonisolated func median(_ values: [TimeInterval]) -> Double? {
    guard !values.isEmpty else { return nil }
    let sorted = values.sorted()
    let middle = sorted.count / 2
    if sorted.count.isMultiple(of: 2) {
        return (sorted[middle - 1] + sorted[middle]) / 2
    }
    return sorted[middle]
}

private nonisolated func validCombination(
    name: RetentionEventName,
    source: RetentionEventSource,
    questID: UUID?
) -> Bool {
    switch name {
    case .appActivated, .experimentExposed, .questCreationStarted, .onboardingDeferred:
        source == .app && questID == nil
    case .questCreated, .questRetried:
        source == .app && questID != nil
    case .questCompleted:
        questID != nil
    }
}

private nonisolated func assignmentOrdering(
    _ lhs: ExperimentAssignmentSnapshot,
    _ rhs: ExperimentAssignmentSnapshot
) -> Bool {
    if lhs.assignedAt != rhs.assignedAt { return lhs.assignedAt < rhs.assignedAt }
    return lhs.installationID.uuidString < rhs.installationID.uuidString
}

private nonisolated func eventOrdering(
    _ lhs: RetentionEventSnapshot,
    _ rhs: RetentionEventSnapshot
) -> Bool {
    if lhs.occurredAt != rhs.occurredAt { return lhs.occurredAt < rhs.occurredAt }
    return lhs.id.uuidString < rhs.id.uuidString
}
