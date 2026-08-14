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
        var quality = QualityAccumulator()

        let installationsByID = supportedInstallationsByID(installations, quality: &quality)
        let validRows = validatedSelections(
            selections,
            installationsByID: installationsByID,
            asOf: asOf,
            quality: &quality
        )
        let selectedDays = makeSelectedDays(
            from: validRows,
            reportingCalendar: reportingCalendar,
            reportingInterval: reportingInterval,
            quality: &quality
        )
        let canonicalEvents = canonicalMeasurementEvents(
            events,
            installationsByID: installationsByID,
            asOf: asOf,
            quality: &quality
        )
        let outcomes = makeOutcomes(
            selectedDays: selectedDays,
            canonicalEvents: canonicalEvents,
            reportingCalendar: reportingCalendar,
            reportingInterval: reportingInterval,
            asOf: asOf
        )

        return DailyFocusReport(
            schemaVersion: currentSchemaVersion,
            generatedAt: asOf,
            timeZoneIdentifier: calendar.timeZone.identifier,
            reportingInterval: reportingInterval,
            dailySelection: outcomes.dailySelection,
            focusQuestCompletion: outcomes.focusQuestCompletion,
            selectedDayCompletion: outcomes.selectedDayCompletion,
            nextDayRevisit: outcomes.nextDayRevisit,
            editRate: outcomes.editRate,
            dataQuality: quality.snapshot
        )
    }

    /// Newest-wins is wrong here: an installation row can be re-created, and the measurement window
    /// must start at the *earliest* known start or every rate silently loses its leading days.
    private static func supportedInstallationsByID(
        _ installations: [RetentionInstallationSnapshot],
        quality: inout QualityAccumulator
    ) -> [UUID: RetentionInstallationSnapshot] {
        var result: [UUID: RetentionInstallationSnapshot] = [:]
        for installation in installations {
            guard installation.schemaVersion == RetentionInstallation.currentSchemaVersion else {
                quality.unsupportedCount += 1
                continue
            }
            if let existing = result[installation.installationID] {
                if installation.measurementStartedAt < existing.measurementStartedAt {
                    result[installation.installationID] = installation
                }
            } else {
                result[installation.installationID] = installation
            }
        }
        return result
    }

    private static func validatedSelections(
        _ selections: [DailyFocusSelectionSnapshot],
        installationsByID: [UUID: RetentionInstallationSnapshot],
        asOf: Date,
        quality: inout QualityAccumulator
    ) -> [DailyFocusSelectionSnapshot] {
        var validRows: [DailyFocusSelectionSnapshot] = []
        for selection in selections {
            guard selection.schemaVersion == DailyFocusSelection.currentSchemaVersion else {
                quality.unsupportedCount += 1
                continue
            }
            guard installationsByID[selection.installationID] != nil else {
                quality.missingInstallationCount += 1
                continue
            }
            guard selection.recordedAt <= asOf else {
                quality.futureCount += 1
                continue
            }
            guard let timeZone = TimeZone(identifier: selection.timeZoneIdentifier),
                  let kind = selection.kind,
                  let questIDs = selection.selectedQuestIDs,
                  (1...3).contains(questIDs.count),
                  Set(questIDs).count == questIDs.count else {
                quality.malformedCount += 1
                continue
            }
            var selectionCalendar = Calendar(identifier: .gregorian)
            selectionCalendar.timeZone = timeZone
            // The row carries its own day key; if it disagrees with its own timestamp the row was
            // written under a different clock and cannot be attributed to a day.
            guard DailyFocusDay.key(for: selection.recordedAt, calendar: selectionCalendar)
                    == selection.localDayKey,
                  kind == .confirmation || kind == .revision else {
                quality.malformedCount += 1
                continue
            }
            validRows.append(selection)
        }
        return validRows
    }

    private static func makeSelectedDays(
        from validRows: [DailyFocusSelectionSnapshot],
        reportingCalendar: Calendar,
        reportingInterval: DateInterval,
        quality: inout QualityAccumulator
    ) -> [SelectedDay] {
        let groupedRows = Dictionary(grouping: validRows) {
            SelectionGroupKey(
                installationID: $0.installationID,
                localDayKey: $0.localDayKey
            )
        }
        var selectedDays: [SelectedDay] = []
        for rows in groupedRows.values {
            guard let day = makeSelectedDay(
                rows: rows,
                reportingCalendar: reportingCalendar,
                reportingInterval: reportingInterval,
                quality: &quality
            ) else { continue }
            selectedDays.append(day)
        }
        return selectedDays
    }

    private static func makeSelectedDay(
        rows: [DailyFocusSelectionSnapshot],
        reportingCalendar: Calendar,
        reportingInterval: DateInterval,
        quality: inout QualityAccumulator
    ) -> SelectedDay? {
        let ordered = deduplicatedRows(rows, quality: &quality).sorted(by: selectionOrdering)
        // A day only counts once the user confirmed it; revisions before that confirmation are
        // out-of-order noise, and a day with no confirmation at all contributes nothing.
        guard let confirmationIndex = ordered.firstIndex(where: { $0.kind == .confirmation }) else {
            quality.outOfOrderCount += ordered.count
            return nil
        }
        quality.outOfOrderCount += confirmationIndex

        let confirmation = ordered[confirmationIndex]
        var firstIncludedAt: [UUID: Date] = [:]
        for questID in confirmation.selectedQuestIDs ?? [] {
            firstIncludedAt[questID] = confirmation.recordedAt
        }

        var hasRevision = false
        for row in ordered.dropFirst(confirmationIndex + 1) {
            if row.kind == .confirmation {
                quality.conflictingCount += 1
                continue
            }
            guard row.kind == .revision else {
                quality.malformedCount += 1
                continue
            }
            hasRevision = true
            // First inclusion wins: a quest added by a later revision starts its completion window
            // then, not at the original confirmation.
            for questID in row.selectedQuestIDs ?? [] where firstIncludedAt[questID] == nil {
                firstIncludedAt[questID] = row.recordedAt
            }
        }

        let dayStart = reportingCalendar.startOfDay(for: confirmation.recordedAt)
        guard reportingInterval.containsHalfOpen(dayStart) else { return nil }
        return SelectedDay(
            installationID: confirmation.installationID,
            dayStart: dayStart,
            firstIncludedAt: firstIncludedAt,
            hasRevision: hasRevision
        )
    }

    /// Rows sharing an (id, recordedAt) position must be byte-identical; a disagreement means the
    /// same write was observed two different ways, so neither copy can be trusted.
    private static func deduplicatedRows(
        _ rows: [DailyFocusSelectionSnapshot],
        quality: inout QualityAccumulator
    ) -> [DailyFocusSelectionSnapshot] {
        let positionGroups = Dictionary(grouping: rows) {
            SelectionPosition(id: $0.id, recordedAt: $0.recordedAt)
        }
        var canonicalRows: [DailyFocusSelectionSnapshot] = []
        for positionRows in positionGroups.values {
            guard let first = positionRows.first else { continue }
            guard positionRows.allSatisfy({ $0 == first }) else {
                quality.conflictingCount += positionRows.count
                continue
            }
            canonicalRows.append(first)
        }
        return canonicalRows
    }

    private static func canonicalMeasurementEvents(
        _ events: [RetentionEventSnapshot],
        installationsByID: [UUID: RetentionInstallationSnapshot],
        asOf: Date,
        quality: inout QualityAccumulator
    ) -> [RetentionEventSnapshot] {
        var validEvents: [RetentionEventSnapshot] = []
        for event in events {
            guard event.schemaVersion == RetentionEvent.currentSchemaVersion,
                  let installation = installationsByID[event.installationID],
                  let source = event.source,
                  event.occurredAt >= installation.measurementStartedAt else {
                continue
            }
            guard event.occurredAt <= asOf else {
                quality.futureCount += 1
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
        return Dictionary(grouping: validEvents, by: \.deduplicationKey)
            .compactMap { $0.value.sorted(by: eventOrdering).first }
    }

    private static func makeOutcomes(
        selectedDays: [SelectedDay],
        canonicalEvents: [RetentionEventSnapshot],
        reportingCalendar: Calendar,
        reportingInterval: DateInterval,
        asOf: Date
    ) -> FocusOutcomes {
        let activeDays = Set(canonicalEvents.compactMap { event -> InstallationDay? in
            guard event.name == .appActivated else { return nil }
            let dayStart = reportingCalendar.startOfDay(for: event.occurredAt)
            guard reportingInterval.containsHalfOpen(dayStart) else { return nil }
            return InstallationDay(installationID: event.installationID, dayStart: dayStart)
        })
        let selectedDayKeys = Set(selectedDays.map {
            InstallationDay(installationID: $0.installationID, dayStart: $0.dayStart)
        })

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

            // A day is only judged once it is over — otherwise an in-progress day counts as a miss.
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

            // Revisit needs the *next* day to be over too, hence day + 2.
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

        return FocusOutcomes(
            dailySelection: RetentionRate(
                achieved: activeDays.intersection(selectedDayKeys).count,
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
            )
        )
    }
}

/// Mirrors `OnboardingExperimentReport`'s accumulator: every rejection path bumps a named field here
/// instead of one of six loose `var`s threaded through a single long function.
private nonisolated struct QualityAccumulator {
    var unsupportedCount = 0
    var malformedCount = 0
    var conflictingCount = 0
    var missingInstallationCount = 0
    var outOfOrderCount = 0
    var futureCount = 0

    var snapshot: DailyFocusDataQuality {
        let partial = unsupportedCount > 0
            || malformedCount > 0
            || conflictingCount > 0
            || missingInstallationCount > 0
            || outOfOrderCount > 0
            || futureCount > 0
        return DailyFocusDataQuality(
            status: partial ? .partial : .complete,
            unsupportedCount: unsupportedCount,
            malformedCount: malformedCount,
            conflictingCount: conflictingCount,
            missingInstallationCount: missingInstallationCount,
            outOfOrderCount: outOfOrderCount,
            futureCount: futureCount
        )
    }
}

private nonisolated struct FocusOutcomes {
    let dailySelection: RetentionRate
    let focusQuestCompletion: RetentionRate
    let selectedDayCompletion: RetentionRate
    let nextDayRevisit: RetentionRate
    let editRate: RetentionRate
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
