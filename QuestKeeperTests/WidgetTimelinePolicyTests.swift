import Foundation
import Testing
@testable import QuestKeeper

@Suite("Widget timeline policy")
struct WidgetTimelinePolicyTests {
    private let now = Date(timeIntervalSinceReferenceDate: 820_454_400)

    @Test("next refresh uses the six-hour urgency threshold when it is sooner than fallback")
    func nextRefreshUsesSixHourUrgencyThreshold() {
        let deadline = now.addingTimeInterval(
            WidgetDungeonDerivation.urgencyWarningLeadTime + 10 * 60
        )
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

    @Test("next refresh uses the due-soon threshold when it is sooner than fallback")
    func nextRefreshUsesDueSoonThreshold() {
        let deadline = now.addingTimeInterval(
            WidgetDungeonDerivation.dueSoonLeadTime + 10 * 60
        )
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

    @Test("next refresh falls back after fifteen minutes for a valid empty payload")
    func nextRefreshFallsBackForValidEmptyPayload() {
        let payload = WidgetDungeonPayload(
            schemaVersion: WidgetDungeonPayload.currentSchemaVersion,
            generatedAt: now,
            quests: []
        )

        let refresh = WidgetDungeonDerivation.nextRefreshDate(payload: payload, after: now)

        #expect(refresh == now.addingTimeInterval(WidgetDungeonDerivation.fallbackRefreshInterval))
    }

    @Test("next refresh includes stale cutoff when it is earlier than fallback")
    func nextRefreshIncludesStaleCutoffForValidPayloads() {
        let generatedAt = now.addingTimeInterval(-(WidgetDungeonDerivation.staleSnapshotAge - 5 * 60))
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
