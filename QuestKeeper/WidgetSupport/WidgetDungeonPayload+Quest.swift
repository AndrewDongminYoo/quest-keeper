import Foundation

extension WidgetDungeonPayload {
    @MainActor
    static func make(from quests: [Quest], generatedAt: Date = .now) -> WidgetDungeonPayload {
        WidgetDungeonPayload(
            schemaVersion: currentSchemaVersion,
            generatedAt: generatedAt,
            quests: quests.map { quest in
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
