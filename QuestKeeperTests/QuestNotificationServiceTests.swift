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

private enum FakeNotificationError: Error {
    case addFailed
}

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

        await service.sync(
            quest: quest(id: questID, title: "리포트", deadlineOffset: 3 * hour),
            now: now,
            locale: Locale(identifier: "ko")
        )

        #expect(center.addedRequests.count == 2)
        let request = center.addedRequests[0]
        let trigger = request.trigger as? UNCalendarNotificationTrigger
        #expect(trigger?.repeats == false)
        #expect(request.content.title == "퀘스트 마감 임박")
        #expect(request.content.body == "퀘스트가 곧 마감됩니다")
        #expect(request.content.userInfo["questID"] as? String == questID.uuidString)
        #expect(request.content.userInfo["kind"] as? String == QuestNotificationKind.dueSoon.rawValue)
    }

    @Test("notification copy resolves per locale and carries no quest title")
    func notificationCopyLocalizes() {
        let ko = Locale(identifier: "ko")
        let en = Locale(identifier: "en")

        #expect(AppStrings.resolve(AppStrings.notificationDueSoonTitle, locale: ko) == "퀘스트 마감 임박")
        #expect(AppStrings.resolve(AppStrings.notificationDueSoonBody, locale: ko) == "퀘스트가 곧 마감됩니다")
        #expect(AppStrings.resolve(AppStrings.notificationDueSoonTitle, locale: en) == "Quest due soon")
        #expect(AppStrings.resolve(AppStrings.notificationDueSoonBody, locale: en) == "One of your quests is due soon")

        #expect(AppStrings.resolve(AppStrings.notificationDeadlineTitle, locale: ko) == "퀘스트 마감")
        #expect(AppStrings.resolve(AppStrings.notificationDeadlineBody, locale: ko) == "퀘스트 마감 시간이 되었습니다")
        #expect(AppStrings.resolve(AppStrings.notificationDeadlineTitle, locale: en) == "Quest deadline")
        #expect(AppStrings.resolve(AppStrings.notificationDeadlineBody, locale: en) == "One of your quests is due now")
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

    @Test("retry tomorrow resync removes old notifications and schedules future requests")
    func retryTomorrowResync() async {
        let center = FakeQuestNotificationCenter()
        let service = makeService(center: center)
        let questID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
        let quest = quest(id: questID, deadlineOffset: -hour)

        QuestActions.retryTomorrow(quest, now: now, calendar: Calendar(identifier: .gregorian))
        await service.sync(quest: quest, now: now)

        let identifiers = QuestNotificationPlanner.identifiers(for: questID)
        #expect(center.removedPendingIdentifiers == [identifiers])
        #expect(center.removedDeliveredIdentifiers == [identifiers])
        #expect(center.addedRequests.map(\.identifier) == identifiers)
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

    @Test("reconcile refreshes existing QuestKeeper requests for current deadlines")
    func reconcileRefreshesExistingRequests() async {
        let center = FakeQuestNotificationCenter()
        let service = makeService(center: center)
        let questID = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
        let identifiers = QuestNotificationPlanner.identifiers(for: questID)
        center.pendingRequestsList = identifiers.map { makeRequest(identifier: $0) }

        await service.reconcile(quests: [quest(id: questID, deadlineOffset: 5 * hour)], now: now)

        #expect(center.removedPendingIdentifiers == [identifiers])
        #expect(center.addedRequests.map(\.identifier) == identifiers)
    }

    @Test("reconcile removes delivered notifications for resolved quests")
    func reconcileRemovesDeliveredResolvedQuestNotifications() async {
        let center = FakeQuestNotificationCenter()
        let service = makeService(center: center)
        let questID = UUID(uuidString: "88888888-8888-8888-8888-888888888888")!
        let identifiers = QuestNotificationPlanner.identifiers(for: questID)

        await service.reconcile(quests: [quest(id: questID, deadlineOffset: -hour)], now: now)

        #expect(center.removedDeliveredIdentifiers == [identifiers])
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

    @Test("permission recovery action distinguishes request and settings paths")
    func permissionRecoveryActionMatchesAuthorization() {
        #expect(QuestNotificationPermissionAction.make(authorization: nil) == nil)
        #expect(QuestNotificationPermissionAction.make(authorization: .notDetermined) == .requestAuthorization)
        #expect(QuestNotificationPermissionAction.make(authorization: .denied) == .openSettings)
        #expect(QuestNotificationPermissionAction.make(authorization: .allowed) == nil)
        #expect(QuestNotificationPermissionAction.make(authorization: .unavailable) == nil)
    }

    @Test("explicit permission recovery requests authorization and reconciles existing quests")
    func permissionRecoveryRequestsAndReconciles() async {
        let center = FakeQuestNotificationCenter(status: .notDetermined)
        let service = makeService(center: center)
        let questID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!

        let authorization = await service.requestAuthorizationAndReconcile(
            quests: [quest(id: questID, deadlineOffset: 3 * hour)],
            now: now
        )

        #expect(authorization == .allowed)
        #expect(center.events.filter { $0 == "requestAuthorization" }.count == 1)
        #expect(center.addedRequests.map(\.identifier) == QuestNotificationPlanner.identifiers(for: questID))
    }

    @Test("shortcut sync never requests undetermined notification permission")
    func shortcutSyncDoesNotPrompt() async {
        let center = FakeQuestNotificationCenter(status: .notDetermined)
        let service = makeService(center: center)
        let snapshot = quest(deadlineOffset: 3 * hour).snapshot

        let authorization = await service.syncWithoutRequestingAuthorization(
            snapshot: snapshot,
            now: now,
            locale: Locale(identifier: "ko")
        )

        #expect(authorization == .notDetermined)
        #expect(center.addedRequests.isEmpty)
        #expect(center.events.contains("requestAuthorization") == false)
    }

    @Test("shortcut sync schedules when permission already exists")
    func shortcutSyncUsesExistingPermission() async {
        let center = FakeQuestNotificationCenter(status: .authorized)
        let service = makeService(center: center)
        let snapshot = quest(deadlineOffset: 3 * hour).snapshot

        let authorization = await service.syncWithoutRequestingAuthorization(
            snapshot: snapshot,
            now: now
        )

        #expect(authorization == .allowed)
        #expect(center.addedRequests.count == 2)
        #expect(center.events.contains("requestAuthorization") == false)
    }

    @Test("shortcut sync reports scheduling failure as unavailable")
    func shortcutSyncReportsAddFailure() async {
        let center = FakeQuestNotificationCenter(status: .authorized)
        center.addError = FakeNotificationError.addFailed
        let service = makeService(center: center)

        let authorization = await service.syncWithoutRequestingAuthorization(
            snapshot: quest(deadlineOffset: 3 * hour).snapshot,
            now: now
        )

        #expect(authorization == .unavailable)
    }

    @Test("sync removes partial Quest requests when a later add fails")
    func syncRemovesPartialRequestsAfterAddFailure() async {
        let center = FakeQuestNotificationCenter(status: .authorized)
        let unrelatedID = "external.notification"
        center.pendingRequestsList = [makeRequest(identifier: unrelatedID)]
        center.addErrorOnAttempt = 2
        let service = makeService(center: center)
        let questID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!

        let authorization = await service.sync(
            quest: quest(id: questID, deadlineOffset: 3 * hour),
            now: now
        )

        let questIdentifiers = QuestNotificationPlanner.identifiers(for: questID)
        #expect(authorization == .unavailable)
        #expect(center.pendingRequestsList.map(\.identifier) == [unrelatedID])
        #expect(center.pendingRequestsList.contains { questIdentifiers.contains($0.identifier) } == false)
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

    private func makeScheduledRequest(identifier: String, fireDate: Date) -> UNNotificationRequest {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(
            [.timeZone, .year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )
        return UNNotificationRequest(
            identifier: identifier,
            content: UNMutableNotificationContent(),
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
    }

    // These two work off `Date.now`, not the suite's fixed `now`. A non-repeating
    // `UNCalendarNotificationTrigger` whose date has passed returns nil from `nextTriggerDate()`,
    // so against the 2023 fixture every seeded request vanishes from the pending set and the cap
    // has nothing to act on — a green that proves nothing. Real future dates keep them visible.
    @Test("a single-quest sync evicts the furthest requests rather than overflowing the platform cap")
    func singleQuestSyncEnforcesTheGlobalCap() async {
        let center = FakeQuestNotificationCenter()
        let service = makeService(center: center)
        let cap = QuestNotificationPlanner.maximumScheduledNotifications
        let base = Date.now

        // A board that has already filled every slot, all of them further out than the new quest.
        let seeded = (0..<cap).map { index in
            makeScheduledRequest(
                identifier: QuestNotificationKind.deadline.identifier(for: UUID()),
                fireDate: base.addingTimeInterval(Double(100 + index) * hour)
            )
        }
        center.pendingRequestsList = seeded

        let questID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
        let newQuest = Quest(
            id: questID,
            title: "빨래",
            deadline: base.addingTimeInterval(3 * hour),
            importance: .medium
        )
        await service.sync(quest: newQuest, now: base)

        let remaining = center.pendingRequestsList.map(\.identifier)
        #expect(remaining.count == cap)
        // The two the sync just added fire soonest, so they are the ones that must survive.
        #expect(remaining.contains(QuestNotificationKind.dueSoon.identifier(for: questID)))
        #expect(remaining.contains(QuestNotificationKind.deadline.identifier(for: questID)))
        // Eviction comes off the far end, not the near one.
        #expect(!remaining.contains(seeded[cap - 1].identifier))
        #expect(!remaining.contains(seeded[cap - 2].identifier))
        #expect(remaining.contains(seeded[0].identifier))
    }

    @Test("a sync that stays under the cap evicts nothing")
    func syncUnderTheCapEvictsNothing() async {
        let center = FakeQuestNotificationCenter()
        let service = makeService(center: center)
        let base = Date.now
        let existing = makeScheduledRequest(
            identifier: QuestNotificationKind.deadline.identifier(for: UUID()),
            fireDate: base.addingTimeInterval(500 * hour)
        )
        center.pendingRequestsList = [existing]
        let newQuest = Quest(
            id: UUID(),
            title: "빨래",
            deadline: base.addingTimeInterval(3 * hour),
            importance: .medium
        )

        await service.sync(quest: newQuest, now: base)

        // The far-future request is well past the cap boundary, so it must survive untouched.
        #expect(center.pendingRequestsList.contains { $0.identifier == existing.identifier })
        #expect(center.pendingRequestsList.count == 3)
        #expect(center.removedPendingIdentifiers.allSatisfy { !$0.contains(existing.identifier) })
    }
}

@MainActor
private final class FakeQuestNotificationCenter: QuestNotificationCenter {
    var status: UNAuthorizationStatus
    var requestAuthorizationResult = true
    var addError: Error?
    var addErrorOnAttempt: Int?
    var addAttemptCount = 0
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
        addAttemptCount += 1
        if addErrorOnAttempt == addAttemptCount { throw FakeNotificationError.addFailed }
        if let addError { throw addError }
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

    func pendingQuestNotifications() async -> [PendingQuestNotification] {
        pendingRequestsList.compactMap { request in
            guard let trigger = request.trigger as? UNCalendarNotificationTrigger,
                  let fireDate = trigger.nextTriggerDate() else { return nil }
            return PendingQuestNotification(identifier: request.identifier, fireDate: fireDate)
        }
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
