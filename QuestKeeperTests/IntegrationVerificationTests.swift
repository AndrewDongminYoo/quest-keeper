import Foundation
import Testing
@testable import QuestKeeper

@MainActor
struct IntegrationVerificationTests {
    private let now = Date(timeIntervalSinceReferenceDate: 820_584_000)
    private let hour: TimeInterval = 60 * 60
    private let day: TimeInterval = 24 * 60 * 60

    @Test("app and widget derive the same victories and visible daily graves")
    func appAndWidgetDeriveSameVictoriesAndDailyGraves() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        let pendingID = UUID()
        let todayGraveID = UUID()
        let oldGraveID = UUID()
        let victoryID = UUID()
        let lateCompletionID = UUID()

        let snapshots = [
            snapshot(id: pendingID, deadline: now.addingTimeInterval(hour), completedAt: nil, importance: .high),
            snapshot(id: todayGraveID, deadline: now.addingTimeInterval(-hour), completedAt: nil, importance: .medium),
            snapshot(id: oldGraveID, deadline: now.addingTimeInterval(-day), completedAt: nil, importance: .medium),
            snapshot(id: victoryID, deadline: now.addingTimeInterval(hour), completedAt: now.addingTimeInterval(-hour), importance: .low),
            snapshot(id: lateCompletionID, deadline: now.addingTimeInterval(-2 * hour), completedAt: now.addingTimeInterval(-hour), importance: .high),
        ]
        let payload = WidgetDungeonPayload(
            schemaVersion: WidgetDungeonPayload.currentSchemaVersion,
            generatedAt: now,
            quests: [
                widgetQuest(id: pendingID, title: "진행 중", deadline: now.addingTimeInterval(hour), completedAt: nil, importance: .high),
                widgetQuest(id: todayGraveID, title: "오늘 놓침", deadline: now.addingTimeInterval(-hour), completedAt: nil, importance: .medium),
                widgetQuest(id: oldGraveID, title: "어제 놓침", deadline: now.addingTimeInterval(-day), completedAt: nil, importance: .medium),
                widgetQuest(id: victoryID, title: "승리", deadline: now.addingTimeInterval(hour), completedAt: now.addingTimeInterval(-hour), importance: .low),
                widgetQuest(id: lateCompletionID, title: "늦은 완료", deadline: now.addingTimeInterval(-2 * hour), completedAt: now.addingTimeInterval(-hour), importance: .high),
            ]
        )

        let hero = HeroDerivation.state(
            quests: snapshots,
            now: now,
            lastOpened: now.addingTimeInterval(-3 * day),
            calendar: calendar
        )
        let widget = WidgetDungeonDerivation.derive(payload: payload, at: now, calendar: calendar)

        #expect(hero.totalVictories == widget.totalVictories)
        #expect(hero.dailyGraves == [todayGraveID, lateCompletionID])
        #expect(widget.dailyGraves.map(\.id) == [todayGraveID, lateCompletionID])
        #expect(hero.dailyGraves == widget.dailyGraves.map(\.id))
        #expect(widget.activeMobs.map(\.id) == [pendingID])
        #expect(widget.dailyGraves.map(\.id).contains(oldGraveID) == false)
        #expect(widget.activeMobs.map(\.id).contains(lateCompletionID) == false)
    }

    @Test("quest mutations keep widget payload facts aligned")
    func questMutationsKeepWidgetPayloadFactsAligned() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        let questID = UUID()
        let quest = Quest(
            id: questID,
            title: "통합 검증",
            deadline: now.addingTimeInterval(hour),
            importance: .high
        )

        let initialPayload = WidgetDungeonPayload.make(from: [quest], generatedAt: now)
        let initialState = WidgetDungeonDerivation.derive(
            payload: initialPayload,
            at: now,
            calendar: calendar
        )
        #expect(initialPayload.quests.map(\.id) == [questID])
        #expect(initialState.activeMobs.map(\.id) == [questID])

        QuestActions.complete(quest, at: now)
        let completedPayload = WidgetDungeonPayload.make(from: [quest], generatedAt: now)
        let completedState = WidgetDungeonDerivation.derive(
            payload: completedPayload,
            at: now,
            calendar: calendar
        )
        #expect(completedPayload.quests.first?.completedAt == now)
        #expect(completedState.totalVictories == 1)
        #expect(completedState.activeMobs.isEmpty)

        QuestActions.retryTomorrow(quest, now: now, calendar: calendar)
        let retriedPayload = WidgetDungeonPayload.make(from: [quest], generatedAt: now)
        let retriedState = WidgetDungeonDerivation.derive(
            payload: retriedPayload,
            at: now,
            calendar: calendar
        )
        #expect(retriedPayload.quests.first?.completedAt == nil)
        let retriedDeadline = try #require(retriedPayload.quests.first?.deadline)
        #expect(retriedDeadline > now)
        #expect(retriedState.activeMobs.map(\.id) == [questID])

        let deletedPayload = WidgetDungeonPayload.make(
            from: [quest],
            excluding: questID,
            generatedAt: now
        )
        #expect(deletedPayload.quests.isEmpty)
    }

    @Test("activation replay reports missed quests once after long inactivity")
    func activationReplayReportsMissedQuestsOnceAfterLongInactivity() {
        let missedWhileAwayID = UUID()
        let missedBeforeAwayID = UUID()
        let completedID = UUID()
        let lastOpened = now.addingTimeInterval(-30 * day)
        let quests = [
            snapshot(id: missedWhileAwayID, deadline: now.addingTimeInterval(-2 * day), completedAt: nil, importance: .medium),
            snapshot(id: missedBeforeAwayID, deadline: now.addingTimeInterval(-40 * day), completedAt: nil, importance: .medium),
            snapshot(id: completedID, deadline: now.addingTimeInterval(-2 * day), completedAt: now.addingTimeInterval(-3 * day), importance: .medium),
        ]

        let first = reconstructOnActivation(quests: quests, now: now, previousLastOpened: lastOpened)
        let second = reconstructOnActivation(quests: quests, now: now, previousLastOpened: first.newLastOpened)

        #expect(first.deaths == [missedWhileAwayID])
        #expect(second.deaths.isEmpty)
    }

    private func snapshot(
        id: UUID,
        deadline: Date,
        completedAt: Date?,
        importance: Importance
    ) -> QuestSnapshot {
        QuestSnapshot(id: id, deadline: deadline, completedAt: completedAt, importance: importance)
    }

    private func widgetQuest(
        id: UUID,
        title: String,
        deadline: Date,
        completedAt: Date?,
        importance: Importance
    ) -> WidgetQuestPayload {
        WidgetQuestPayload(
            id: id,
            title: title,
            deadline: deadline,
            completedAt: completedAt,
            importanceRawValue: importance.rawValue
        )
    }
}
