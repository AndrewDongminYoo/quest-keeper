import Foundation
import Testing
@testable import QuestKeeper

@Suite("Widget dungeon payload")
struct WidgetDungeonPayloadTests {
    private let now = Date(timeIntervalSinceReferenceDate: 820_454_400)
    private let hour: TimeInterval = 60 * 60
    private let day: TimeInterval = 24 * 60 * 60

    @Test("payload round trips raw widget facts")
    func payloadRoundTripsRawFacts() throws {
        let questID = UUID()
        let payload = WidgetDungeonPayload(
            schemaVersion: WidgetDungeonPayload.currentSchemaVersion,
            generatedAt: now,
            quests: [
                WidgetQuestPayload(
                    id: questID,
                    title: "물 마시기",
                    deadline: now.addingTimeInterval(hour),
                    completedAt: nil,
                    importanceRawValue: 2
                )
            ]
        )

        let data = try JSONEncoder.widgetDungeon.encode(payload)
        let decoded = try JSONDecoder.widgetDungeon.decode(WidgetDungeonPayload.self, from: data)

        #expect(decoded == payload)
    }

    @Test("derivation exposes active mobs, daily graves, and victories")
    func derivationBuildsWidgetState() {
        let activeID = UUID()
        let dailyGraveID = UUID()
        let oldGraveID = UUID()
        let victoryID = UUID()
        let payload = WidgetDungeonPayload(
            schemaVersion: WidgetDungeonPayload.currentSchemaVersion,
            generatedAt: now,
            quests: [
                WidgetQuestPayload(
                    id: activeID,
                    title: "리뷰하기",
                    deadline: now.addingTimeInterval(hour),
                    completedAt: nil,
                    importanceRawValue: 3
                ),
                WidgetQuestPayload(
                    id: dailyGraveID,
                    title: "아침 산책",
                    deadline: now.addingTimeInterval(-hour),
                    completedAt: nil,
                    importanceRawValue: 1
                ),
                WidgetQuestPayload(
                    id: oldGraveID,
                    title: "어제 운동",
                    deadline: now.addingTimeInterval(-day),
                    completedAt: nil,
                    importanceRawValue: 2
                ),
                WidgetQuestPayload(
                    id: victoryID,
                    title: "샤워하기",
                    deadline: now.addingTimeInterval(hour),
                    completedAt: now.addingTimeInterval(-hour),
                    importanceRawValue: 1
                )
            ]
        )

        let state = WidgetDungeonDerivation.derive(
            payload: payload,
            at: now,
            calendar: Calendar(identifier: .gregorian)
        )

        #expect(state.activeMobs.map(\.id) == [activeID])
        #expect(state.dailyGraves.map(\.id) == [dailyGraveID])
        #expect(state.totalVictories == 1)
        #expect(state.isStale == false)
    }

    @Test("active mobs are sorted by urgency")
    func activeMobsAreSortedAndLimited() {
        let lateID = UUID()
        let soonID = UUID()
        let payload = WidgetDungeonPayload(
            schemaVersion: WidgetDungeonPayload.currentSchemaVersion,
            generatedAt: now,
            quests: [
                WidgetQuestPayload(id: lateID, title: "나중", deadline: now.addingTimeInterval(6 * hour), completedAt: nil, importanceRawValue: 3),
                WidgetQuestPayload(id: soonID, title: "곧", deadline: now.addingTimeInterval(30 * 60), completedAt: nil, importanceRawValue: 1)
            ]
        )

        let state = WidgetDungeonDerivation.derive(payload: payload, at: now)

        #expect(state.activeMobs.map(\.id) == [soonID, lateID])
        #expect(state.activeMobs.first?.mobLevel == 3)
    }

    @Test("payload factory preserves quest titles and raw facts")
    @MainActor
    func payloadFactoryPreservesRawFacts() throws {
        let quest = Quest(
            id: UUID(),
            title: "홈 위젯 만들기",
            deadline: now.addingTimeInterval(hour),
            importance: .high,
            completedAt: nil
        )

        let payload = WidgetDungeonPayload.make(from: [quest], generatedAt: now)

        #expect(payload.schemaVersion == WidgetDungeonPayload.currentSchemaVersion)
        #expect(payload.generatedAt == now)
        #expect(payload.quests == [
            WidgetQuestPayload(
                id: quest.id,
                title: "홈 위젯 만들기",
                deadline: quest.deadline,
                completedAt: nil,
                importanceRawValue: Importance.high.rawValue
            )
        ])
    }
}
