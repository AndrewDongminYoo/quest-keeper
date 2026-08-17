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

    @Test("the desired set is ordered by fire date across quests, not by quest")
    func desiredSetIsFireDateOrdered() {
        // Concatenating per-quest plans interleaves them: the near quest's deadline (+2.5h) would
        // land ahead of the far quest's due-soon (+2h) even though it fires later.
        let near = snapshot(deadlineOffset: 2.5 * hour)
        let far = snapshot(deadlineOffset: 3 * hour)

        let plans = QuestNotificationPlanner.plans(for: [near, far], now: now)

        #expect(plans.map(\.fireDate) == [
            now.addingTimeInterval(1.5 * hour),
            now.addingTimeInterval(2 * hour),
            now.addingTimeInterval(2.5 * hour),
            now.addingTimeInterval(3 * hour),
        ])
    }

    @Test("the desired set is capped, dropping the furthest-firing requests")
    func desiredSetIsCappedSoonestFirst() {
        let cap = QuestNotificationPlanner.maximumScheduledNotifications
        // Two plans per quest, so this deliberately overshoots the cap.
        let snapshots = (0..<cap).map { snapshot(deadlineOffset: Double(2 + $0) * hour) }

        let plans = QuestNotificationPlanner.plans(for: snapshots, now: now)

        #expect(plans.count == cap)
        #expect(plans.map(\.fireDate) == plans.map(\.fireDate).sorted())
        // The uncapped set would reach the last quest's deadline; the cap must cut before it.
        let furthest = now.addingTimeInterval(Double(1 + cap) * hour)
        #expect(plans.allSatisfy { $0.fireDate < furthest })
    }

    @Test(
        "notification previews do not disclose quest titles",
        arguments: [
            (Locale(identifier: "ko"), ["퀘스트가 곧 마감됩니다", "퀘스트 마감 시간이 되었습니다"]),
            (Locale(identifier: "en"), ["One of your quests is due soon", "One of your quests is due now"]),
        ]
    )
    func notificationPreviewsKeepQuestTitlesPrivate(locale: Locale, expectedBodies: [String]) {
        // The planner takes no title argument at all, so a private quest title has
        // no path into a notification body — the bodies are fixed localized constants.
        let plans = QuestNotificationPlanner.plans(
            for: snapshot(deadlineOffset: 3 * hour),
            now: now,
            locale: locale
        )

        #expect(plans.map(\.body) == expectedBodies)
    }
}
