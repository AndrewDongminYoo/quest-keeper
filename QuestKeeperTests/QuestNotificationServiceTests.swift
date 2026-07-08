//
//  QuestNotificationServiceTests.swift
//  QuestKeeperTests
//
//  Phase 3 — notification service lifecycle tests with a fake notification center.
//

import Foundation
import Testing
import UserNotifications
@testable import QuestKeeper

@MainActor
struct QuestNotificationServiceTests {
    let now = Date(timeIntervalSinceReferenceDate: 700_000_000)
    let hour: TimeInterval = 60 * 60

    private func makeService(center: FakeQuestNotificationCenter) -> QuestNotificationService {
        QuestNotificationService(center: center, calendar: Calendar(identifier: .gregorian))
    }

    func quest(
        id: UUID = UUID(),
        title: String = "빨래",
        deadlineOffset: TimeInterval,
        completedAt: Date? = nil
    ) -> Quest {
        Quest(id: id, title: title, deadline: now.addingTimeInterval(deadlineOffset), importance: .medium, completedAt: completedAt)
    }

    @Test("service builds non-repeating calendar requests with quest userInfo")
    func calendarTriggerContent() async {
        let center = FakeQuestNotificationCenter()
        let service = makeService(center: center)
        let questID = UUID()

        await service.sync(quest: quest(id: questID, title: "리포트", deadlineOffset: 3 * hour), now: now)

        #expect(center.addedRequests.count == 2)
        let request = center.addedRequests[0]
        let trigger = request.trigger as? UNCalendarNotificationTrigger
        #expect(trigger?.repeats == false)
        #expect(request.content.title == "퀘스트 마감 임박")
        #expect(request.content.body == "리포트 · 곧 마감됩니다")
        #expect(request.content.userInfo["questID"] as? String == questID.uuidString)
        #expect(request.content.userInfo["kind"] as? String == QuestNotificationKind.dueSoon.rawValue)
    }

    @Test("sync removes deterministic identifiers before adding replacements")
    func editLifecycleRemovesBeforeAdd() async {
        let center = FakeQuestNotificationCenter()
        let service = makeService(center: center)
        let questID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let identifiers = QuestNotificationPlanner.identifiers(for: questID)

        await service.sync(quest: quest(id: questID, deadlineOffset: 3 * hour), now: now)

        #expect(center.events.first == "removePending:\(identifiers.joined(separator: ","))")
        #expect(center.events.dropFirst().first == "removeDelivered:\(identifiers.joined(separator: ","))")
        #expect(center.events.dropFirst(2).allSatisfy { $0.hasPrefix("add:") })
    }

    @Test("latest sync replaces earlier trigger dates for the same quest")
    func latestSyncWins() async {
        let center = FakeQuestNotificationCenter()
        let service = makeService(center: center)
        let questID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

        await service.sync(quest: quest(id: questID, deadlineOffset: 3 * hour), now: now)
        await service.sync(quest: quest(id: questID, deadlineOffset: 5 * hour), now: now)

        let deadlineID = QuestNotificationKind.deadline.identifier(for: questID)
        let deadlineRequest = center.pendingRequestsList.first { $0.identifier == deadlineID }
        let trigger = deadlineRequest?.trigger as? UNCalendarNotificationTrigger
        let expected = Calendar(identifier: .gregorian).dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: now.addingTimeInterval(5 * hour)
        )

        #expect(center.pendingRequestsList.count == 2)
        #expect(trigger?.dateComponents.year == expected.year)
        #expect(trigger?.dateComponents.month == expected.month)
        #expect(trigger?.dateComponents.day == expected.day)
        #expect(trigger?.dateComponents.hour == expected.hour)
        #expect(trigger?.dateComponents.minute == expected.minute)
        #expect(trigger?.dateComponents.second == expected.second)
    }

    @Test("cancel removes pending and delivered notifications")
    func completionCancellation() async {
        let center = FakeQuestNotificationCenter()
        let service = makeService(center: center)
        let questID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

        await service.cancel(questID: questID)

        let identifiers = QuestNotificationPlanner.identifiers(for: questID)
        #expect(center.removedPendingIdentifiers == [identifiers])
        #expect(center.removedDeliveredIdentifiers == [identifiers])
    }

    @Test("reconcile removes stale QuestKeeper notification requests")
    func reconcileRemovesStaleRequests() async {
        let center = FakeQuestNotificationCenter()
        let service = makeService(center: center)
        let staleID = "quest.44444444-4444-4444-4444-444444444444.deadline"
        center.pendingRequestsList = [
            makeRequest(identifier: staleID),
            makeRequest(identifier: "external.notification"),
        ]

        await service.reconcile(quests: [], now: now)

        #expect(center.removedPendingIdentifiers == [[staleID]])
        #expect(center.pendingRequestsList.map(\.identifier) == ["external.notification"])
    }

    @Test("reconcile schedules missing expected requests")
    func reconcileSchedulesMissingRequests() async {
        let center = FakeQuestNotificationCenter()
        let service = makeService(center: center)
        let questID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!

        await service.reconcile(quests: [quest(id: questID, deadlineOffset: 3 * hour)], now: now)

        #expect(center.addedRequests.map(\.identifier) == [
            QuestNotificationKind.dueSoon.identifier(for: questID),
            QuestNotificationKind.deadline.identifier(for: questID),
        ])
    }

    @Test("reconcile does not request authorization when status is not determined")
    func reconcileDoesNotPromptForPermission() async {
        let center = FakeQuestNotificationCenter(status: .notDetermined)
        let service = makeService(center: center)

        let authorization = await service.reconcile(quests: [quest(deadlineOffset: 3 * hour)], now: now)

        #expect(authorization == .notDetermined)
        #expect(center.addedRequests.isEmpty)
        #expect(center.events.contains("requestAuthorization") == false)
    }

    @Test("denied permission skips scheduling without throwing")
    func deniedPermissionDoesNotFailSavePath() async {
        let center = FakeQuestNotificationCenter(status: .denied)
        let service = makeService(center: center)

        let authorization = await service.sync(quest: quest(deadlineOffset: 3 * hour), now: now)

        #expect(authorization == .denied)
        #expect(center.addedRequests.isEmpty)
        #expect(center.removedPendingIdentifiers.count == 1)
    }

    private func makeRequest(identifier: String) -> UNNotificationRequest {
        UNNotificationRequest(identifier: identifier, content: UNMutableNotificationContent(), trigger: nil)
    }
}

@MainActor
private final class FakeQuestNotificationCenter: QuestNotificationCenter {
    var status: UNAuthorizationStatus
    var requestAuthorizationResult = true
    var addedRequests: [UNNotificationRequest] = []
    var pendingRequestsList: [UNNotificationRequest] = []
    var removedPendingIdentifiers: [[String]] = []
    var removedDeliveredIdentifiers: [[String]] = []
    var events: [String] = []

    init(status: UNAuthorizationStatus = .authorized) {
        self.status = status
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        status
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        events.append("requestAuthorization")
        status = requestAuthorizationResult ? .authorized : .denied
        return requestAuthorizationResult
    }

    func add(_ request: UNNotificationRequest) async throws {
        events.append("add:\(request.identifier)")
        addedRequests.append(request)
        pendingRequestsList.append(request)
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        pendingRequestsList
    }

    func pendingNotificationIdentifiers() async -> [String] {
        pendingRequestsList.map(\.identifier)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        events.append("removePending:\(identifiers.joined(separator: ","))")
        removedPendingIdentifiers.append(identifiers)
        pendingRequestsList.removeAll { identifiers.contains($0.identifier) }
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        events.append("removeDelivered:\(identifiers.joined(separator: ","))")
        removedDeliveredIdentifiers.append(identifiers)
    }
}
