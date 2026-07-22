import Foundation

nonisolated struct DailyFocusDataQuality: Codable, Equatable, Sendable {
    let status: RetentionDataQualityStatus
    let unsupportedCount: Int
    let malformedCount: Int
    let conflictingCount: Int
    let missingInstallationCount: Int
    let outOfOrderCount: Int
    let futureCount: Int
}
nonisolated struct DailyFocusReport: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let generatedAt: Date
    let timeZoneIdentifier: String
    let reportingInterval: DateInterval
    let dailySelection: RetentionRate
    let focusQuestCompletion: RetentionRate
    let selectedDayCompletion: RetentionRate
    let nextDayRevisit: RetentionRate
    let editRate: RetentionRate
    let dataQuality: DailyFocusDataQuality

    static func make(
        selections: [DailyFocusSelectionSnapshot],
        installations: [RetentionInstallationSnapshot],
        events: [RetentionEventSnapshot],
        asOf: Date,
        calendar: Calendar,
        reportingInterval: DateInterval
    ) -> DailyFocusReport {
        let reportingCalendar = DailyFocusDay.gregorianCalendar(timeZone: calendar.timeZone)
        var unsupportedCount = 0
        var malformedCount = 0
        var conflictingCount = 0
        var missingInstallationCount = 0
        var outOfOrderCount = 0
        var futureCount = 0

        let supportedInstallations = installations.reduce(
            into: [UUID: RetentionInstallationSnapshot]()
        ) { result, installation in
            guard installation.schemaVersion == RetentionInstallation.currentSchemaVersion else {
                unsupportedCount += 1
                return
            }
            if let existing = result[installation.installationID] {
                if installation.measurementStartedAt < existing.measurementStartedAt {
                    result[installation.installationID] = installation
                }
            } else {
                result[installation.installationID] = installation
            }
        }

        var validRows: [DailyFocusSelectionSnapshot] = []
        for selection in selections {
            guard selection.schemaVersion == DailyFocusSelection.currentSchemaVersion else {
                unsupportedCount += 1
                continue
            }
            guard supportedInstallations[selection.installationID] != nil else {
                missingInstallationCount += 1
                continue
            }
            guard selection.recordedAt <= asOf else {
                futureCount += 1
                continue
            }
            guard let timeZone = TimeZone(identifier: selection.timeZoneIdentifier),
                  let kind = selection.kind,
                  let questIDs = selection.selectedQuestIDs,
                  (1...3).contains(questIDs.count),
                  Set(questIDs).count == questIDs.count else {
                malformedCount += 1
                continue
            }
            var selectionCalendar = Calendar(identifier: .gregorian)
            selectionCalendar.timeZone = timeZone
            guard DailyFocusDay.key(for: selection.recordedAt, calendar: selectionCalendar)
                    == selection.localDayKey,
                  kind == .confirmation || kind == .revision else {
                malformedCount += 1
                continue
            }
            validRows.append(selection)
        }

        let groupedRows = Dictionary(grouping: validRows) {
            SelectionGroupKey(
                installationID: $0.installationID,
                localDayKey: $0.localDayKey
            )
        }
        var selectedDays: [SelectedDay] = []
        for rows in groupedRows.values {
            let positionGroups = Dictionary(grouping: rows) {
                SelectionPosition(id: $0.id, recordedAt: $0.recordedAt)
            }
            var canonicalRows: [DailyFocusSelectionSnapshot] = []
            for positionRows in positionGroups.values {
                guard let first = positionRows.first else { continue }
                guard positionRows.allSatisfy({ $0 == first }) else {
                    conflictingCount += positionRows.count
                    continue
                }
                canonicalRows.append(first)
            }
            let ordered = canonicalRows.sorted(by: selectionOrdering)
            guard let confirmationIndex = ordered.firstIndex(where: { $0.kind == .confirmation }) else {
                outOfOrderCount += ordered.count
                continue
            }
            outOfOrderCount += confirmationIndex
            let confirmation = ordered[confirmationIndex]
            var firstIncludedAt: [UUID: Date] = [:]
            for questID in confirmation.selectedQuestIDs ?? [] {
                firstIncludedAt[questID] = confirmation.recordedAt
            }

            var hasRevision = false
            for row in ordered.dropFirst(confirmationIndex + 1) {
                if row.kind == .confirmation {
                    conflictingCount += 1
                    continue
                }
                guard row.kind == .revision else {
                    malformedCount += 1
                    continue
                }
                hasRevision = true
                for questID in row.selectedQuestIDs ?? [] where firstIncludedAt[questID] == nil {
                    firstIncludedAt[questID] = row.recordedAt
                }
            }

            let dayStart = reportingCalendar.startOfDay(for: confirmation.recordedAt)
            guard reportingInterval.containsHalfOpen(dayStart) else { continue }
            selectedDays.append(SelectedDay(
                installationID: confirmation.installationID,
                dayStart: dayStart,
                firstIncludedAt: firstIncludedAt,
                hasRevision: hasRevision
            ))
        }

        var validEvents: [RetentionEventSnapshot] = []
        for event in events {
            guard event.schemaVersion == RetentionEvent.currentSchemaVersion,
                  let installation = supportedInstallations[event.installationID],
                  let source = event.source,
                  event.occurredAt >= installation.measurementStartedAt else {
                continue
            }
            guard event.occurredAt <= asOf else {
                futureCount += 1
                continue
            }
            switch event.name {
            case .appActivated where source == .app && event.questID == nil:
                validEvents.append(event)
            case .questCompleted where event.questID != nil:
                validEvents.append(event)
            default:
                continue
            }
        }
        let canonicalEvents = Dictionary(grouping: validEvents, by: \.deduplicationKey)
            .compactMap { $0.value.sorted(by: eventOrdering).first }

        let activeDays = Set(canonicalEvents.compactMap { event -> InstallationDay? in
            guard event.name == .appActivated else { return nil }
            let dayStart = reportingCalendar.startOfDay(for: event.occurredAt)
            guard reportingInterval.containsHalfOpen(dayStart) else { return nil }
            return InstallationDay(installationID: event.installationID, dayStart: dayStart)
        })
        let selectedDayKeys = Set(selectedDays.map {
            InstallationDay(installationID: $0.installationID, dayStart: $0.dayStart)
        })
        let selectedActiveDays = activeDays.intersection(selectedDayKeys)

        var completedQuestCount = 0
        var eligibleQuestCount = 0
        var completedSelectedDayCount = 0
        var eligibleSelectedDayCount = 0
        var revisitCount = 0
        var revisitEligibleCount = 0

        for day in selectedDays {
            guard let nextDay = reportingCalendar.date(byAdding: .day, value: 1, to: day.dayStart),
                  let dayAfterNext = reportingCalendar.date(byAdding: .day, value: 2, to: day.dayStart) else {
                continue
            }

            if nextDay <= asOf {
                eligibleSelectedDayCount += 1
                eligibleQuestCount += day.firstIncludedAt.count
                var completedAny = false
                for (questID, firstIncludedAt) in day.firstIncludedAt {
                    let completed = canonicalEvents.contains {
                        $0.installationID == day.installationID
                            && $0.name == .questCompleted
                            && $0.questID == questID
                            && $0.occurredAt >= firstIncludedAt
                            && $0.occurredAt < nextDay
                    }
                    if completed {
                        completedQuestCount += 1
                        completedAny = true
                    }
                }
                if completedAny { completedSelectedDayCount += 1 }
            }

            if dayAfterNext <= asOf {
                revisitEligibleCount += 1
                let revisited = canonicalEvents.contains {
                    $0.installationID == day.installationID
                        && $0.name == .appActivated
                        && reportingCalendar.isDate($0.occurredAt, inSameDayAs: nextDay)
                }
                if revisited { revisitCount += 1 }
            }
        }

        let qualityCounts = [
            unsupportedCount,
            malformedCount,
            conflictingCount,
            missingInstallationCount,
            outOfOrderCount,
            futureCount,
        ]
        return DailyFocusReport(
            schemaVersion: currentSchemaVersion,
            generatedAt: asOf,
            timeZoneIdentifier: calendar.timeZone.identifier,
            reportingInterval: reportingInterval,
            dailySelection: RetentionRate(
                achieved: selectedActiveDays.count,
                eligible: activeDays.count
            ),
            focusQuestCompletion: RetentionRate(
                achieved: completedQuestCount,
                eligible: eligibleQuestCount
            ),
            selectedDayCompletion: RetentionRate(
                achieved: completedSelectedDayCount,
                eligible: eligibleSelectedDayCount
            ),
            nextDayRevisit: RetentionRate(
                achieved: revisitCount,
                eligible: revisitEligibleCount
            ),
            editRate: RetentionRate(
                achieved: selectedDays.count(where: \.hasRevision),
                eligible: selectedDays.count
            ),
            dataQuality: DailyFocusDataQuality(
                status: qualityCounts.allSatisfy { $0 == 0 } ? .complete : .partial,
                unsupportedCount: unsupportedCount,
                malformedCount: malformedCount,
                conflictingCount: conflictingCount,
                missingInstallationCount: missingInstallationCount,
                outOfOrderCount: outOfOrderCount,
                futureCount: futureCount
            )
        )
    }
}

nonisolated private struct SelectionGroupKey: Hashable {
    let installationID: UUID
    let localDayKey: String
}

nonisolated private struct SelectionPosition: Hashable {
    let id: UUID
    let recordedAt: Date
}

nonisolated private struct InstallationDay: Hashable {
    let installationID: UUID
    let dayStart: Date
}

nonisolated private struct SelectedDay {
    let installationID: UUID
    let dayStart: Date
    let firstIncludedAt: [UUID: Date]
    let hasRevision: Bool
}

nonisolated private func selectionOrdering(
    _ lhs: DailyFocusSelectionSnapshot,
    _ rhs: DailyFocusSelectionSnapshot
) -> Bool {
    if lhs.recordedAt != rhs.recordedAt { return lhs.recordedAt < rhs.recordedAt }
    return lhs.id.uuidString.lowercased() < rhs.id.uuidString.lowercased()
}

nonisolated private func eventOrdering(
    _ lhs: RetentionEventSnapshot,
    _ rhs: RetentionEventSnapshot
) -> Bool {
    if lhs.occurredAt != rhs.occurredAt { return lhs.occurredAt < rhs.occurredAt }
    return lhs.id.uuidString.lowercased() < rhs.id.uuidString.lowercased()
}

private extension DateInterval {
    nonisolated func containsHalfOpen(_ date: Date) -> Bool {
        date >= start && date < end
    }
}
