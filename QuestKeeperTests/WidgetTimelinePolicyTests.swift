import Foundation
import Testing
@testable import QuestKeeper

@Suite("Widget timeline policy")
struct WidgetTimelinePolicyTests {
    private let now = Date(timeIntervalSinceReferenceDate: 820_454_400)

    @Test("next refresh uses the six-hour urgency threshold before due soon")
    func nextRefreshUsesSixHourUrgencyThreshold() {
        let deadline = now.addingTimeInterval(8 * 60 * 60)
        let payload = WidgetDungeonPayload(
            schemaVersion: WidgetDungeonPayload.currentSchemaVersion,
            generatedAt: now,
            quests: [
                WidgetQuestPayload(
                    id: UUID(),
                    title: "긴급도 상승",
                    deadline: deadline,
                    completedAt: nil,
                    importanceRawValue: 2
                )
            ]
        )

        let refresh = WidgetDungeonDerivation.nextRefreshDate(payload: payload, after: now)

        #expect(refresh == deadline.addingTimeInterval(-WidgetDungeonDerivation.urgencyWarningLeadTime))
    }

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

    @Test("next refresh includes stale cutoff for valid payloads")
    func nextRefreshIncludesStaleCutoffForValidPayloads() {
        let generatedAt = now.addingTimeInterval(-(WidgetDungeonDerivation.staleSnapshotAge - 30 * 60))
        let payload = WidgetDungeonPayload(
            schemaVersion: WidgetDungeonPayload.currentSchemaVersion,
            generatedAt: generatedAt,
            quests: []
        )

        let refresh = WidgetDungeonDerivation.nextRefreshDate(payload: payload, after: now)

        #expect(refresh == generatedAt.addingTimeInterval(WidgetDungeonDerivation.staleSnapshotAge))
    }

    @Test("next refresh falls back when no usable cache payload exists")
    func nextRefreshFallsBackWhenNoUsableCachePayloadExists() {
        let refresh = WidgetDungeonDerivation.nextRefreshDate(payload: .empty, after: now)

        #expect(refresh == now.addingTimeInterval(WidgetDungeonDerivation.fallbackRefreshInterval))
    }
}
