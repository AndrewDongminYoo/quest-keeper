import Foundation

extension WidgetDungeonPayload {
    @MainActor
    static func make(
        from quests: [Quest],
        including changedQuest: Quest? = nil,
        excluding excludedQuestID: UUID? = nil,
        generatedAt: Date = .now
    ) -> WidgetDungeonPayload {
        var effectiveQuests = quests

        if let changedQuest {
            if let existingIndex = effectiveQuests.firstIndex(where: { $0.id == changedQuest.id }) {
                effectiveQuests[existingIndex] = changedQuest
            } else {
                effectiveQuests.append(changedQuest)
            }
        }

        if let excludedQuestID {
            effectiveQuests.removeAll { $0.id == excludedQuestID }
        }

        return WidgetDungeonPayload(
            schemaVersion: currentSchemaVersion,
            generatedAt: generatedAt,
            quests: effectiveQuests.map { quest in
                WidgetQuestPayload(
                    id: quest.id,
                    title: quest.title,
                    deadline: quest.deadline,
                    completedAt: quest.completedAt,
                    importanceRawValue: quest.importance.rawValue
                )
            }
        )
    }
}
