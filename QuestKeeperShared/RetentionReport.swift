import Foundation

nonisolated struct RetentionRate: Codable, Equatable, Sendable {
    let achieved: Int
    let eligible: Int

    var value: Double? {
        eligible == 0 ? nil : Double(achieved) / Double(eligible)
    }
}

nonisolated enum RetentionDataQualityStatus: String, Codable, Equatable, Sendable {
    case complete
    case partial
}

nonisolated struct RetentionDataQuality: Codable, Equatable, Sendable {
    let status: RetentionDataQualityStatus
    let duplicateCountsByEvent: [String: Int]
    let missingCount: Int
    let forbiddenCount: Int
    let unsupportedCount: Int
    let orphanCompletionCount: Int
    let preActivationCreationCount: Int
    let preMeasurementCount: Int
    let futureCount: Int
}

nonisolated struct RetentionScenarioExpectation: Equatable, Sendable {
    let requiredKeys: Set<String>
    let forbiddenKeys: Set<String>
}

nonisolated struct RetentionScenarioValidation: Codable, Equatable, Sendable {
    let missingKeys: Set<String>
    let forbiddenKeys: Set<String>
}

nonisolated struct RetentionReport: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let generatedAt: Date
    let timeZoneIdentifier: String
    let reportingWeek: DateInterval
    let firstValue: RetentionRate
    let firstCompletion: RetentionRate
    let d1: RetentionRate
    let d7: RetentionRate
    let weeklyActiveInstallations: Int
    let weeklyRepeatedCompletion: RetentionRate
    let dataQuality: RetentionDataQuality
    let scenarioValidation: RetentionScenarioValidation

    static func make(
        installations: [RetentionInstallationSnapshot],
        events: [RetentionEventSnapshot],
        asOf: Date,
        calendar: Calendar,
        reportingWeek: DateInterval,
        expectation: RetentionScenarioExpectation? = nil
    ) -> RetentionReport {
        var unsupportedCount = installations.count { $0.schemaVersion != RetentionInstallation.currentSchemaVersion }
        let supportedInstallations = installations
            .filter { $0.schemaVersion == RetentionInstallation.currentSchemaVersion }
            .reduce(into: [UUID: RetentionInstallationSnapshot]()) { result, installation in
                if let existing = result[installation.installationID] {
                    if installation.measurementStartedAt < existing.measurementStartedAt {
                        result[installation.installationID] = installation
                    }
                } else {
                    result[installation.installationID] = installation
                }
            }

        var preMeasurementCount = 0
        var futureCount = 0
        var validEvents: [RetentionEventSnapshot] = []
        for event in events {
            guard event.schemaVersion == RetentionEvent.currentSchemaVersion,
                  let name = event.name,
                  let source = event.source,
                  isValidCombination(name: name, source: source, questID: event.questID),
                  let installation = supportedInstallations[event.installationID]
            else {
                unsupportedCount += 1
                continue
            }
            guard event.occurredAt >= installation.measurementStartedAt else {
                preMeasurementCount += 1
                continue
            }
            guard event.occurredAt <= asOf else {
                futureCount += 1
                continue
            }
            validEvents.append(event)
        }

        var duplicateCountsByEvent: [String: Int] = [:]
        let canonicalEvents = Dictionary(grouping: validEvents, by: \.deduplicationKey)
            .compactMap { _, rows -> RetentionEventSnapshot? in
                let sorted = rows.sorted(by: eventOrdering)
                for duplicate in sorted.dropFirst() {
                    duplicateCountsByEvent[duplicate.nameRawValue, default: 0] += 1
                }
                return sorted.first
            }
            .sorted(by: eventOrdering)

        let canonicalKeys = Set(canonicalEvents.map(\.deduplicationKey))
        let scenarioValidation = RetentionScenarioValidation(
            missingKeys: expectation?.requiredKeys.subtracting(canonicalKeys) ?? [],
            forbiddenKeys: expectation?.forbiddenKeys.intersection(canonicalKeys) ?? []
        )
        let eventsByInstallation = Dictionary(grouping: canonicalEvents, by: \.installationID)

        var firstValueEligible = 0
        var firstValueAchieved = 0
        var firstCompletionAchieved = 0
        var orphanCompletionCount = 0
        var preActivationCreationCount = 0
        var d1Eligible = 0
        var d1Achieved = 0
        var d7Eligible = 0
        var d7Achieved = 0

        for installation in supportedInstallations.values {
            let ordered = (eventsByInstallation[installation.installationID] ?? []).sorted(by: eventOrdering)
            for (index, event) in ordered.enumerated() where event.name == .questCompleted {
                let hasEarlierCreation = ordered[..<index].contains { $0.name == .questCreated }
                if !hasEarlierCreation { orphanCompletionCount += 1 }
            }

            let activationIndex = ordered.firstIndex(where: { $0.name == .appActivated })
            if let activationIndex {
                preActivationCreationCount += ordered[..<activationIndex].count { $0.name == .questCreated }
            } else {
                preActivationCreationCount += ordered.count { $0.name == .questCreated }
            }
            guard let activationIndex else { continue }
            firstValueEligible += 1
            let activation = ordered[activationIndex]

            if let creationIndex = ordered.indices.first(where: {
                $0 > activationIndex && ordered[$0].name == .questCreated
            }) {
                firstValueAchieved += 1
                if ordered.indices.contains(where: {
                    $0 > creationIndex && ordered[$0].name == .questCompleted
                }) {
                    firstCompletionAchieved += 1
                }
            }

            let activationDates = ordered
                .filter { $0.name == .appActivated }
                .map { calendar.startOfDay(for: $0.occurredAt) }
            let cohortDate = calendar.startOfDay(for: activation.occurredAt)
            updateRetention(
                dayOffset: 1,
                cohortDate: cohortDate,
                activationDates: activationDates,
                asOf: asOf,
                calendar: calendar,
                eligible: &d1Eligible,
                achieved: &d1Achieved
            )
            updateRetention(
                dayOffset: 7,
                cohortDate: cohortDate,
                activationDates: activationDates,
                asOf: asOf,
                calendar: calendar,
                eligible: &d7Eligible,
                achieved: &d7Achieved
            )
        }

        let weeklyActiveIDs = Set(canonicalEvents.lazy.filter {
            $0.name == .appActivated && reportingWeek.containsHalfOpen($0.occurredAt)
        }.map(\.installationID))
        let weeklyCompletionCounts = Dictionary(grouping: canonicalEvents.lazy.filter {
            $0.name == .questCompleted && reportingWeek.containsHalfOpen($0.occurredAt)
        }, by: \.installationID).mapValues(\.count)
        let weeklyRepeated = weeklyActiveIDs.count {
            weeklyCompletionCounts[$0, default: 0] >= 2
        }

        let missingCount = scenarioValidation.missingKeys.count
        let forbiddenCount = scenarioValidation.forbiddenKeys.count
        let hasQualityProblem = duplicateCountsByEvent.values.reduce(0, +) > 0
            || missingCount > 0
            || forbiddenCount > 0
            || unsupportedCount > 0
            || orphanCompletionCount > 0
            || preActivationCreationCount > 0
            || preMeasurementCount > 0
            || futureCount > 0

        return RetentionReport(
            schemaVersion: currentSchemaVersion,
            generatedAt: asOf,
            timeZoneIdentifier: calendar.timeZone.identifier,
            reportingWeek: reportingWeek,
            firstValue: RetentionRate(achieved: firstValueAchieved, eligible: firstValueEligible),
            firstCompletion: RetentionRate(achieved: firstCompletionAchieved, eligible: firstValueAchieved),
            d1: RetentionRate(achieved: d1Achieved, eligible: d1Eligible),
            d7: RetentionRate(achieved: d7Achieved, eligible: d7Eligible),
            weeklyActiveInstallations: weeklyActiveIDs.count,
            weeklyRepeatedCompletion: RetentionRate(
                achieved: weeklyRepeated,
                eligible: weeklyActiveIDs.count
            ),
            dataQuality: RetentionDataQuality(
                status: hasQualityProblem ? .partial : .complete,
                duplicateCountsByEvent: duplicateCountsByEvent,
                missingCount: missingCount,
                forbiddenCount: forbiddenCount,
                unsupportedCount: unsupportedCount,
                orphanCompletionCount: orphanCompletionCount,
                preActivationCreationCount: preActivationCreationCount,
                preMeasurementCount: preMeasurementCount,
                futureCount: futureCount
            ),
            scenarioValidation: scenarioValidation
        )
    }

    func renderMarkdown() -> String {
        let duplicates = dataQuality.duplicateCountsByEvent.keys.sorted().map {
            "- Duplicate \($0): \(dataQuality.duplicateCountsByEvent[$0, default: 0])."
        }
        let lines = [
            "# QuestKeeper Synthetic Retention Baseline",
            "",
            "This report uses synthetic fixture data and is not evidence of real user performance.",
            "Fixture version: 1.",
            "Report schema version: \(schemaVersion).",
            "Generated at: \(Self.iso8601(generatedAt)).",
            "Time zone: \(timeZoneIdentifier).",
            "Reporting week: \(Self.iso8601(reportingWeek.start)) to \(Self.iso8601(reportingWeek.end)), end exclusive.",
            "",
            "## Funnel",
            "",
            "First value: \(Self.render(firstValue)).",
            "First completion: \(Self.render(firstCompletion)).",
            "D1 retention: \(Self.render(d1)).",
            "D7 retention: \(Self.render(d7)).",
            "Weekly active installations: \(weeklyActiveInstallations).",
            "Weekly repeated completion: \(Self.render(weeklyRepeatedCompletion)).",
            "",
            "## Data Quality",
            "",
            "Status: \(dataQuality.status.rawValue).",
            "- Duplicate rows: \(dataQuality.duplicateCountsByEvent.values.reduce(0, +)).",
        ] + duplicates + [
            "- Missing scenario keys: \(dataQuality.missingCount).",
            "- Forbidden scenario keys: \(dataQuality.forbiddenCount).",
            "- Unsupported rows: \(dataQuality.unsupportedCount).",
            "- Orphan completions: \(dataQuality.orphanCompletionCount).",
            "- Pre-activation creations: \(dataQuality.preActivationCreationCount).",
            "- Pre-measurement rows: \(dataQuality.preMeasurementCount).",
            "- Future rows: \(dataQuality.futureCount).",
            "",
            "## Reproduce",
            "",
            "```bash",
            "xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/RetentionReportTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2",
            "```",
            "",
        ]
        return lines.joined(separator: "\n")
    }

    private static func render(_ rate: RetentionRate) -> String {
        guard let value = rate.value else { return "\(rate.achieved) / \(rate.eligible), N/A" }
        let percentage = String(format: "%.1f%%", locale: Locale(identifier: "en_US_POSIX"), value * 100)
        return "\(rate.achieved) / \(rate.eligible), \(percentage)"
    }

    private static func iso8601(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}

private nonisolated func isValidCombination(
    name: RetentionEventName,
    source: RetentionEventSource,
    questID: UUID?
) -> Bool {
    switch name {
    case .appActivated:
        source == .app && questID == nil
    case .questCreated, .questRetried:
        source == .app && questID != nil
    case .questCompleted:
        questID != nil
    }
}

private nonisolated func eventOrdering(_ lhs: RetentionEventSnapshot, _ rhs: RetentionEventSnapshot) -> Bool {
    if lhs.occurredAt != rhs.occurredAt { return lhs.occurredAt < rhs.occurredAt }
    return lhs.id.uuidString < rhs.id.uuidString
}

private nonisolated func updateRetention(
    dayOffset: Int,
    cohortDate: Date,
    activationDates: [Date],
    asOf: Date,
    calendar: Calendar,
    eligible: inout Int,
    achieved: inout Int
) {
    guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: cohortDate),
          let observationEnd = calendar.date(byAdding: .day, value: 1, to: targetDate),
          observationEnd <= asOf
    else { return }
    eligible += 1
    if activationDates.contains(targetDate) { achieved += 1 }
}

private extension DateInterval {
    nonisolated func containsHalfOpen(_ date: Date) -> Bool {
        date >= start && date < end
    }
}
