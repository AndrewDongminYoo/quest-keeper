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

    @Test("empty payload derives to a non-stale empty state at now")
    func emptyPayloadDerivesToNonStaleEmptyState() {
        let state = WidgetDungeonDerivation.derive(payload: .empty, at: now)

        #expect(state.activeMobs.isEmpty)
        #expect(state.dailyGraves.isEmpty)
        #expect(state.totalVictories == 0)
        #expect(state.generatedAt == now)
        #expect(state.isStale == false)
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

    @Test("valid payload becomes stale after stale snapshot age")
    func validPayloadBecomesStaleAfterStaleSnapshotAge() {
        let generatedAt = now.addingTimeInterval(-(WidgetDungeonDerivation.staleSnapshotAge + 60))
        let payload = WidgetDungeonPayload(
            schemaVersion: WidgetDungeonPayload.currentSchemaVersion,
            generatedAt: generatedAt,
            quests: [
                WidgetQuestPayload(
                    id: UUID(),
                    title: "오래된 스냅샷",
                    deadline: now.addingTimeInterval(hour),
                    completedAt: nil,
                    importanceRawValue: 1
                )
            ]
        )

        let state = WidgetDungeonDerivation.derive(payload: payload, at: now)

        #expect(state.isStale == true)
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

    @Test("payload factory appends changed quest when stale source list is missing it")
    @MainActor
    func payloadFactoryAppendsChangedQuestWhenMissingFromSource() {
        let existingQuest = Quest(
            id: UUID(),
            title: "기존 퀘스트",
            deadline: now.addingTimeInterval(hour),
            importance: .medium,
            completedAt: nil
        )
        let changedQuest = Quest(
            id: UUID(),
            title: "새 퀘스트",
            deadline: now.addingTimeInterval(2 * hour),
            importance: .high,
            completedAt: nil
        )

        let payload = WidgetDungeonPayload.make(
            from: [existingQuest],
            including: changedQuest,
            generatedAt: now
        )

        #expect(payload.quests == [
            WidgetQuestPayload(
                id: existingQuest.id,
                title: existingQuest.title,
                deadline: existingQuest.deadline,
                completedAt: existingQuest.completedAt,
                importanceRawValue: existingQuest.importance.rawValue
            ),
            WidgetQuestPayload(
                id: changedQuest.id,
                title: changedQuest.title,
                deadline: changedQuest.deadline,
                completedAt: changedQuest.completedAt,
                importanceRawValue: changedQuest.importance.rawValue
            )
        ])
    }

    @Test("payload factory replaces stale same-id quest facts with changed quest facts")
    @MainActor
    func payloadFactoryReplacesStaleFactsForChangedQuest() {
        let questID = UUID()
        let staleQuest = Quest(
            id: questID,
            title: "예전 제목",
            deadline: now.addingTimeInterval(hour),
            importance: .low,
            completedAt: nil
        )
        let changedQuest = Quest(
            id: questID,
            title: "새 제목",
            deadline: now.addingTimeInterval(3 * hour),
            importance: .high,
            completedAt: now
        )

        let payload = WidgetDungeonPayload.make(
            from: [staleQuest],
            including: changedQuest,
            generatedAt: now
        )

        #expect(payload.quests == [
            WidgetQuestPayload(
                id: changedQuest.id,
                title: changedQuest.title,
                deadline: changedQuest.deadline,
                completedAt: changedQuest.completedAt,
                importanceRawValue: changedQuest.importance.rawValue
            )
        ])
    }

    @Test("payload factory excludes deleted quest from stale source list")
    @MainActor
    func payloadFactoryExcludesDeletedQuestFromStaleSource() {
        let deletedQuest = Quest(
            id: UUID(),
            title: "삭제될 퀘스트",
            deadline: now.addingTimeInterval(hour),
            importance: .medium,
            completedAt: nil
        )
        let survivingQuest = Quest(
            id: UUID(),
            title: "남는 퀘스트",
            deadline: now.addingTimeInterval(2 * hour),
            importance: .high,
            completedAt: nil
        )

        let payload = WidgetDungeonPayload.make(
            from: [deletedQuest, survivingQuest],
            excluding: deletedQuest.id,
            generatedAt: now
        )

        #expect(payload.quests == [
            WidgetQuestPayload(
                id: survivingQuest.id,
                title: survivingQuest.title,
                deadline: survivingQuest.deadline,
                completedAt: survivingQuest.completedAt,
                importanceRawValue: survivingQuest.importance.rawValue
            )
        ])
    }
}
