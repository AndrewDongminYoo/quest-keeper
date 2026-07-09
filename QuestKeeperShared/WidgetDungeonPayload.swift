import Foundation

nonisolated struct WidgetDungeonPayload: Codable, Sendable, Equatable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let generatedAt: Date
    let quests: [WidgetQuestPayload]

    static let empty = WidgetDungeonPayload(
        schemaVersion: currentSchemaVersion,
        generatedAt: .distantPast,
        quests: []
    )
}

nonisolated struct WidgetQuestPayload: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let deadline: Date
    let completedAt: Date?
    let importanceRawValue: Int
}

nonisolated extension JSONEncoder {
    static var widgetDungeon: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

nonisolated extension JSONDecoder {
    static var widgetDungeon: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
