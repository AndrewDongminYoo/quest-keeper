//
//  QuestNotificationPlannerTests.swift
//  QuestKeeperTests
//
//  Phase 3 — pure notification planning tests. No real notification center involved.
//

import Foundation
import Testing
@testable import QuestKeeper

struct QuestNotificationPlannerTests {
    let now = Date(timeIntervalSinceReferenceDate: 700_000_000)
    let hour: TimeInterval = 60 * 60

    func snapshot(
        id: UUID = UUID(),
        deadlineOffset: TimeInterval,
        completedOffset: TimeInterval? = nil
    ) -> QuestSnapshot {
        QuestSnapshot(
            id: id,
            deadline: now.addingTimeInterval(deadlineOffset),
            completedAt: completedOffset.map { now.addingTimeInterval($0) },
            importance: .medium
        )
    }

    @Test("notification identifiers are deterministic")
    func deterministicIdentifiers() {
        let questID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

        #expect(QuestNotificationPlanner.identifiers(for: questID) == [
            "quest.11111111-1111-1111-1111-111111111111.dueSoon",
            "quest.11111111-1111-1111-1111-111111111111.deadline",
        ])
    }

    @Test("past deadlines return no notification plans")
    func pastDeadlineSkipsScheduling() {
        let plans = QuestNotificationPlanner.plans(
            for: snapshot(deadlineOffset: -hour),
            title: "빨래",
            now: now
        )

        #expect(plans.isEmpty)
    }

    @Test("completed quests return no notification plans")
    func completedQuestSkipsScheduling() {
        let plans = QuestNotificationPlanner.plans(
            for: snapshot(deadlineOffset: 2 * hour, completedOffset: -hour),
            title: "운동",
            now: now
        )

        #expect(plans.isEmpty)
    }

    @Test("due-soon plan is skipped when its fire date already passed")
    func dueSoonSkipDeadlineKeep() {
        let plans = QuestNotificationPlanner.plans(
            for: snapshot(deadlineOffset: 30 * 60),
            title: "리포트",
            now: now
        )

        #expect(plans.map(\.kind) == [.deadline])
    }

    @Test("future quests schedule due-soon and deadline plans in order")
    func futureQuestSchedulesBoth() {
        let questID = UUID()
        let plans = QuestNotificationPlanner.plans(
            for: snapshot(id: questID, deadlineOffset: 3 * hour),
            title: "헬스장 가기",
            now: now
        )

        #expect(plans.map(\.kind) == [.dueSoon, .deadline])
        #expect(plans.map(\.questID) == [questID, questID])
        #expect(plans[0].fireDate == now.addingTimeInterval(2 * hour))
        #expect(plans[1].fireDate == now.addingTimeInterval(3 * hour))
    }
}
