import Foundation

nonisolated struct WidgetDungeonEntryState: Sendable, Equatable {
    let date: Date
    let generatedAt: Date
    let activeMobs: [WidgetMobState]
    let dailyGraves: [WidgetMobState]
    let totalVictories: Int
    let isStale: Bool

    static func empty(date: Date) -> WidgetDungeonEntryState {
        WidgetDungeonEntryState(
            date: date,
            generatedAt: date,
            activeMobs: [],
            dailyGraves: [],
            totalVictories: 0,
            isStale: false
        )
    }
}

nonisolated struct WidgetMobState: Sendable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let deadline: Date
    let importanceRawValue: Int
    let urgencyLevel: Int
    let mobLevel: Int
}

nonisolated enum WidgetDungeonDerivation {
    static let maxMobLevel = 5
    static let staleSnapshotAge: TimeInterval = 24 * 60 * 60
    static let fallbackRefreshInterval: TimeInterval = 15 * 60
    static let urgencyHorizon: TimeInterval = 7 * 24 * 60 * 60
    static let urgencyWarningLeadTime: TimeInterval = 6 * 60 * 60
    static let dueSoonLeadTime: TimeInterval = 60 * 60

    static func derive(
        payload: WidgetDungeonPayload,
        at date: Date,
        calendar: Calendar = .current
    ) -> WidgetDungeonEntryState {
        guard isUsablePayload(payload) else {
            return .empty(date: date)
        }

        var activeMobs: [WidgetMobState] = []
        var dailyGraves: [WidgetMobState] = []
        var totalVictories = 0

        for quest in payload.quests {
            let urgencyLevel = urgencyLevel(deadline: quest.deadline, at: date)
            let mob = WidgetMobState(
                id: quest.id,
                title: quest.title,
                deadline: quest.deadline,
                importanceRawValue: quest.importanceRawValue,
                urgencyLevel: urgencyLevel,
                mobLevel: mobLevel(
                    deadline: quest.deadline,
                    importanceRawValue: quest.importanceRawValue,
                    at: date
                )
            )

            if let completedAt = quest.completedAt {
                if completedAt <= quest.deadline {
                    totalVictories += 1
                } else if calendar.isDate(quest.deadline, inSameDayAs: date) {
                    dailyGraves.append(mob)
                }
                continue
            }

            if quest.deadline > date {
                activeMobs.append(mob)
            } else if calendar.isDate(quest.deadline, inSameDayAs: date) {
                dailyGraves.append(mob)
            }
        }

        activeMobs.sort { left, right in
            if left.deadline == right.deadline {
                return left.mobLevel > right.mobLevel
            }
            return left.deadline < right.deadline
        }

        dailyGraves.sort { left, right in
            left.deadline > right.deadline
        }

        return WidgetDungeonEntryState(
            date: date,
            generatedAt: payload.generatedAt,
            activeMobs: activeMobs,
            dailyGraves: dailyGraves,
            totalVictories: totalVictories,
            isStale: date.timeIntervalSince(payload.generatedAt) > staleSnapshotAge
        )
    }

    static func nextRefreshDate(
        payload: WidgetDungeonPayload,
        after date: Date
    ) -> Date {
        let thresholdDates = payload.quests
            .filter { $0.completedAt == nil && $0.deadline > date }
            .flatMap { quest in
                nextUrgencyThresholds(for: quest, after: date)
            }
        let staleCutoff = payload.generatedAt.addingTimeInterval(staleSnapshotAge)
        let fallbackRefresh = date.addingTimeInterval(fallbackRefreshInterval)
        let refreshCandidates = thresholdDates + [staleCutoff, fallbackRefresh]
        let futureCandidates = refreshCandidates
            .filter { $0 > date }
            .sorted()

        return futureCandidates.first ?? fallbackRefresh
    }

    private static func urgencyLevel(deadline: Date, at date: Date) -> Int {
        let remaining = deadline.timeIntervalSince(date)
        if remaining <= 0 { return 4 }
        if remaining <= 60 * 60 { return 3 }
        if remaining <= 6 * 60 * 60 { return 2 }
        return 1
    }

    private static func mobLevel(deadline: Date, importanceRawValue: Int, at date: Date) -> Int {
        guard deadline > date else { return 0 }
        let remaining = deadline.timeIntervalSince(date)
        guard remaining < urgencyHorizon else { return 0 }

        let urgency = 1 - remaining / urgencyHorizon
        let raw = Double(importanceRawValue) * urgency
        return Int((raw / 3.0 * Double(maxMobLevel)).rounded())
    }

    private static func isUsablePayload(_ payload: WidgetDungeonPayload) -> Bool {
        payload.schemaVersion == WidgetDungeonPayload.currentSchemaVersion && (
            payload.generatedAt != .distantPast || !payload.quests.isEmpty
        )
    }

    private static func nextUrgencyThresholds(for quest: WidgetQuestPayload, after date: Date) -> [Date] {
        [
            quest.deadline.addingTimeInterval(-urgencyWarningLeadTime),
            quest.deadline.addingTimeInterval(-dueSoonLeadTime),
            quest.deadline,
        ]
        .filter { $0 > date }
    }
}
