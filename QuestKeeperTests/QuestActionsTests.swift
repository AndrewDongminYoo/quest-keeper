//
//  QuestActionsTests.swift
//  QuestKeeperTests
//
//  Phase 2 — logic seams: completion-as-fact, the deletion guard, and activation reconstruction.
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

    // 3
    @Test("graves are undeletable; pending and victory are deletable")
    func canDeleteGuard() {
        let grave = QuestSnapshot(id: UUID(), deadline: now.addingTimeInterval(-day), completedAt: nil, importance: .medium)
        let pending = QuestSnapshot(id: UUID(), deadline: now.addingTimeInterval(day), completedAt: nil, importance: .medium)
        let victory = QuestSnapshot(id: UUID(), deadline: now.addingTimeInterval(day), completedAt: now.addingTimeInterval(-day), importance: .medium)

        #expect(QuestActions.canDelete(grave, at: now) == false)
        #expect(QuestActions.canDelete(pending, at: now) == true)
        #expect(QuestActions.canDelete(victory, at: now) == true)
    }

    // 4
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
}
