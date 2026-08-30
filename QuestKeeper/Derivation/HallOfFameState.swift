import Foundation

nonisolated enum HallOfFameState {
    static func victoryQuestIDs(quests: [QuestSnapshot], now: Date) -> [UUID] {
        let victories = quests.compactMap { quest -> (id: UUID, completedAt: Date)? in
            guard quest.outcome(at: now) == .victory,
                  let completedAt = quest.completedAt else {
                return nil
            }
            return (id: quest.id, completedAt: completedAt)
        }
        return victories
            .sorted { lhs, rhs in
                if lhs.completedAt != rhs.completedAt { return lhs.completedAt > rhs.completedAt }
                return lhs.id.uuidString.lowercased() < rhs.id.uuidString.lowercased()
            }
            .map(\.id)
    }
}
