import Foundation
import Testing
@testable import QuestKeeper

@Suite("Widget timeline policy")
struct WidgetTimelinePolicyTests {
    private let now = Date(timeIntervalSinceReferenceDate: 820_454_400)

    @Test("next refresh uses the next due soon threshold")
    func nextRefreshUsesDueSoonThreshold() {
        let deadline = now.addingTimeInterval(3 * 60 * 60)
        let payload = WidgetDungeonPayload(
            schemaVersion: WidgetDungeonPayload.currentSchemaVersion,
            generatedAt: now,
            quests: [
                WidgetQuestPayload(
                    id: UUID(),
                    title: "긴급도 확인",
                    deadline: deadline,
                    completedAt: nil,
                    importanceRawValue: 2
                )
            ]
        )

        let refresh = WidgetDungeonDerivation.nextRefreshDate(payload: payload, after: now)

        #expect(refresh == deadline.addingTimeInterval(-WidgetDungeonDerivation.dueSoonLeadTime))
    }

    @Test("next refresh falls back when no pending quest exists")
    func nextRefreshFallsBackWhenNoPendingQuestExists() {
        let payload = WidgetDungeonPayload(
            schemaVersion: WidgetDungeonPayload.currentSchemaVersion,
            generatedAt: now,
            quests: []
        )

        let refresh = WidgetDungeonDerivation.nextRefreshDate(payload: payload, after: now)

        #expect(refresh == now.addingTimeInterval(WidgetDungeonDerivation.fallbackRefreshInterval))
    }
}
