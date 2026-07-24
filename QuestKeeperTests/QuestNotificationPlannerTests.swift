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
            now: now
        )

        #expect(plans.isEmpty)
    }

    @Test("completed quests return no notification plans")
    func completedQuestSkipsScheduling() {
        let plans = QuestNotificationPlanner.plans(
            for: snapshot(deadlineOffset: 2 * hour, completedOffset: -hour),
            now: now
        )

        #expect(plans.isEmpty)
    }

    @Test("due-soon plan is skipped when its fire date already passed")
    func dueSoonSkipDeadlineKeep() {
        let plans = QuestNotificationPlanner.plans(
            for: snapshot(deadlineOffset: 30 * 60),
            now: now
        )

        #expect(plans.map(\.kind) == [.deadline])
    }

    @Test("future quests schedule due-soon and deadline plans in order")
    func futureQuestSchedulesBoth() {
        let questID = UUID()
        let plans = QuestNotificationPlanner.plans(
            for: snapshot(id: questID, deadlineOffset: 3 * hour),
            now: now
        )

        #expect(plans.map(\.kind) == [.dueSoon, .deadline])
        #expect(plans.map(\.questID) == [questID, questID])
        #expect(plans[0].fireDate == now.addingTimeInterval(2 * hour))
        #expect(plans[1].fireDate == now.addingTimeInterval(3 * hour))
    }

    @Test("notification previews do not disclose quest titles")
    func notificationPreviewsKeepQuestTitlesPrivate() {
        // The planner takes no title argument at all, so a private quest title has
        // no path into a notification body — the bodies are fixed localized constants.
        let plans = QuestNotificationPlanner.plans(
            for: snapshot(deadlineOffset: 3 * hour),
            now: now
        )

        #expect(plans.map(\.body) == [
            String(localized: "퀘스트가 곧 마감됩니다"),
            String(localized: "퀘스트 마감 시간이 되었습니다"),
        ])
    }
}
