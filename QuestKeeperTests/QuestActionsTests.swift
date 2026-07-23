//
//  QuestActionsTests.swift
//  QuestKeeperTests
//
//  Phase 2 — logic seams: completion-as-fact, retry tomorrow, and activation reconstruction.
//  See docs/specs/003-crud-hero-view.md.
//

import Testing
import Foundation
import SwiftData
@testable import QuestKeeper

@MainActor
struct QuestActionsTests {
    let now = Date(timeIntervalSinceReferenceDate: 700_000_000)
    let day: TimeInterval = 24 * 60 * 60

    func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Quest.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    // 1
    @Test("complete writes a fact, not a deletion; uncomplete reverts to pending")
    func completeWritesFact() throws {
        let context = try makeContext()
        let quest = Quest(title: "빨래", deadline: now.addingTimeInterval(day), importance: .medium)
        context.insert(quest)

        QuestActions.complete(quest, at: now)
        #expect(quest.completedAt == now)
        #expect(try context.fetch(FetchDescriptor<Quest>()).count == 1)   // still present, not deleted

        QuestActions.uncomplete(quest)
        #expect(quest.completedAt == nil)
        #expect(quest.snapshot.outcome(at: now) == .pending)
    }

    // 2
    @Test("on-time completion is a victory")
    func onTimeCompletionIsVictory() throws {
        let context = try makeContext()
        let quest = Quest(title: "운동", deadline: now.addingTimeInterval(day), importance: .low)
        context.insert(quest)

        QuestActions.complete(quest, at: now)   // before the deadline
        #expect(quest.snapshot.outcome(at: now.addingTimeInterval(2 * day)) == .victory)
    }

    @Test("complete records the action timestamp even near a deadline")
    func completeRecordsActionTimestampNearDeadline() {
        let deadline = Date(timeIntervalSinceReferenceDate: 820_584_000)
        let actionTime = deadline.addingTimeInterval(-0.1)
        let quest = Quest(title: "Finish before the gate closes", deadline: deadline, importance: .medium)

        QuestActions.complete(quest, at: actionTime)

        #expect(quest.completedAt == actionTime)
        #expect(quest.snapshot.outcome(at: deadline.addingTimeInterval(1)) == .victory)
    }

    // 3
    @Test("delete is raw cleanup, not a permanent grave rule")
    func canDeleteIsNotPermanentGraveRule() {
        let grave = QuestSnapshot(id: UUID(), deadline: now.addingTimeInterval(-day), completedAt: nil, importance: .medium)
        let pending = QuestSnapshot(id: UUID(), deadline: now.addingTimeInterval(day), completedAt: nil, importance: .medium)
        let victory = QuestSnapshot(id: UUID(), deadline: now.addingTimeInterval(day), completedAt: now.addingTimeInterval(-day), importance: .medium)

        #expect(QuestActions.canDelete(grave, at: now))
        #expect(QuestActions.canDelete(pending, at: now))
        #expect(QuestActions.canDelete(victory, at: now))
    }

    // 4
    @Test("retry tomorrow moves deadline future, clears completion, and keeps importance")
    func retryTomorrowMutatesRawFactsOnly() throws {
        let context = try makeContext()
        let quest = Quest(
            title: "리팩터",
            deadline: now.addingTimeInterval(-day),
            importance: .high,
            completedAt: now.addingTimeInterval(-60)
        )
        context.insert(quest)

        QuestActions.retryTomorrow(quest, now: now, calendar: Calendar(identifier: .gregorian))

        #expect(quest.deadline > now)
        #expect(quest.completedAt == nil)
        #expect(quest.importance == .high)
        #expect(quest.snapshot.outcome(at: now) == .pending)
    }

    // 5
    @Test("chunking guide triggers only for oversized deadlines")
    func chunkingGuideTrigger() {
        let far = now.addingTimeInterval(GameBalance.longQuestWarningHorizon + 60)
        let near = now.addingTimeInterval(GameBalance.longQuestWarningHorizon - 60)

        #expect(QuestActions.needsChunkingGuide(deadline: far, now: now))
        #expect(QuestActions.needsChunkingGuide(deadline: near, now: now) == false)
    }

    // 6
    @Test("activation surfaces deaths once; the advanced clock replays nothing")
    func reconstructionOrdering() {
        let died = UUID()
        let quests = [
            QuestSnapshot(id: died, deadline: now.addingTimeInterval(-day), completedAt: nil, importance: .medium),
        ]
        let previous = now.addingTimeInterval(-2 * day)   // deadline (-1d) falls within (previous, now]

        let first = reconstructOnActivation(quests: quests, now: now, previousLastOpened: previous)
        #expect(first.deaths == [died])
        #expect(first.newLastOpened == now)

        // Re-run with the advanced lastOpened: the same death is not replayed.
        let second = reconstructOnActivation(quests: quests, now: now, previousLastOpened: first.newLastOpened)
        #expect(second.deaths.isEmpty)
    }

    @Test("advanced activation clock cannot recreate the same recovery offer")
    func recoveryOfferUsesPreviousActivationOnce() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let previous = calendar.date(byAdding: .day, value: -3, to: now)!
        let questID = UUID()
        let quests = [
            QuestSnapshot(
                id: questID,
                deadline: now.addingTimeInterval(600),
                completedAt: nil,
                importance: .medium
            ),
        ]
        let first = reconstructOnActivation(
            quests: quests,
            now: now,
            previousLastOpened: previous
        )
        let firstOffer = RecoveryState.offer(
            previousLastOpened: previous,
            now: now,
            calendar: calendar,
            deathsWhileAway: first.deaths,
            hasStoredQuests: true,
            dailyFocusPresentation: .recommended([questID]),
            variant: .singleQuest
        )
        let secondOffer = RecoveryState.offer(
            previousLastOpened: first.newLastOpened,
            now: now,
            calendar: calendar,
            deathsWhileAway: [],
            hasStoredQuests: true,
            dailyFocusPresentation: .recommended([questID]),
            variant: .singleQuest
        )

        #expect(firstOffer != nil)
        #expect(secondOffer == nil)
    }
}
