import Foundation

nonisolated enum DailyFocusPresentationState: Equatable, Sendable {
    case disabled
    case empty
    case recommended([UUID])
    case confirmed(selectedQuestIDs: [UUID], completedQuestIDs: Set<UUID>)
}
nonisolated enum DailyFocusState {
    static func make(
        enabled: Bool,
        quests: [QuestSnapshot],
        selections: [DailyFocusSelectionSnapshot],
        now: Date,
        calendar: Calendar
    ) -> DailyFocusPresentationState {
        guard enabled else { return .disabled }

        let dayKey = DailyFocusDay.key(for: now, calendar: calendar)
        let orderedRows = selections
            .filter {
                $0.schemaVersion == DailyFocusSelection.currentSchemaVersion
                    && $0.localDayKey == dayKey
                    && $0.kind != nil
                    && isValidSelection($0.selectedQuestIDs ?? [])
            }
            .groupedByPositionRemovingConflicts()
            .sorted(by: selectionOrdering)

        guard let confirmationIndex = orderedRows.firstIndex(where: { $0.kind == .confirmation }) else {
            let recommendation = recommend(quests: quests, now: now)
            return recommendation.isEmpty ? .empty : .recommended(recommendation)
        }

        let validRows = orderedRows[confirmationIndex...].filter {
            $0 == orderedRows[confirmationIndex] || $0.kind == .revision
        }
        guard let latest = validRows.last, let selectedIDs = latest.selectedQuestIDs else {
            let recommendation = recommend(quests: quests, now: now)
            return recommendation.isEmpty ? .empty : .recommended(recommendation)
        }

        let questsByID = Dictionary(uniqueKeysWithValues: quests.map { ($0.id, $0) })
        let visibleSelectedIDs = selectedIDs.filter { id in
            guard let quest = questsByID[id] else { return false }
            return quest.outcome(at: now) != .grave
        }
        let completedIDs = Set(visibleSelectedIDs.filter { id in
            guard let quest = questsByID[id],
                  quest.outcome(at: now) == .victory,
                  let completedAt = quest.completedAt else {
                return false
            }
            return calendar.isDate(completedAt, inSameDayAs: now)
        })
        return .confirmed(
            selectedQuestIDs: visibleSelectedIDs,
            completedQuestIDs: completedIDs
        )
    }

    static func recommend(
        quests: [QuestSnapshot],
        now: Date
    ) -> [UUID] {
        Array(rankedPendingQuestIDs(quests: quests, now: now).prefix(3))
    }

    static func rankedPendingQuestIDs(
        quests: [QuestSnapshot],
        now: Date
    ) -> [UUID] {
        quests
            .filter { $0.outcome(at: now) == .pending }
            .sorted(by: recommendationOrdering)
            .map(\.id)
    }

    static func isValidSelection(_ questIDs: [UUID]) -> Bool {
        (1...3).contains(questIDs.count) && Set(questIDs).count == questIDs.count
    }

    static func remainingPendingQuestIDs(
        pendingQuestIDs: [UUID],
        selectedQuestIDs: [UUID]
    ) -> [UUID] {
        let selected = Set(selectedQuestIDs)
        return pendingQuestIDs.filter { !selected.contains($0) }
    }

    private static func recommendationOrdering(
        _ lhs: QuestSnapshot,
        _ rhs: QuestSnapshot
    ) -> Bool {
        if lhs.deadline != rhs.deadline { return lhs.deadline < rhs.deadline }
        if lhs.importance != rhs.importance {
            return lhs.importance.rawValue > rhs.importance.rawValue
        }
        return lhs.id.uuidString.lowercased() < rhs.id.uuidString.lowercased()
    }

    private static func selectionOrdering(
        _ lhs: DailyFocusSelectionSnapshot,
        _ rhs: DailyFocusSelectionSnapshot
    ) -> Bool {
        if lhs.recordedAt != rhs.recordedAt { return lhs.recordedAt < rhs.recordedAt }
        return lhs.id.uuidString.lowercased() < rhs.id.uuidString.lowercased()
    }
}

private extension Array where Element == DailyFocusSelectionSnapshot {
    nonisolated func groupedByPositionRemovingConflicts() -> [Element] {
        Dictionary(grouping: self) {
            DailyFocusSelectionPosition(id: $0.id, recordedAt: $0.recordedAt)
        }.values.compactMap { rows in
            guard let first = rows.first, rows.allSatisfy({ $0 == first }) else { return nil }
            return first
        }
    }
}

nonisolated private struct DailyFocusSelectionPosition: Hashable {
    let id: UUID
    let recordedAt: Date
}
