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

    private func makeService(
        center: FakeQuestNotificationCenter,
        settings: ReengagementReminderSettings = ReengagementReminderSettings()
    ) -> QuestNotificationService {
        QuestNotificationService(
            center: center,
            calendar: Calendar(identifier: .gregorian),
            reengagementSettingsStore: makeSettingsStore(settings)
        )
    }

    private func makeSettingsStore(
        _ settings: ReengagementReminderSettings
    ) -> ReengagementReminderSettingsStore {
        let defaults = UserDefaults(suiteName: "QuestKeeperTests.\(UUID().uuidString)")!
        let store = ReengagementReminderSettingsStore(defaults: defaults)
        store.save(settings)
        return store
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

    @Test("reconcile restores the previous valid schedule when a later add fails")
    func reconcileRestoresPreviousScheduleAfterAddFailure() async {
        let center = FakeQuestNotificationCenter()
        let service = makeService(center: center)
        let previousQuestID = UUID(uuidString: "ABABABAB-ABAB-ABAB-ABAB-ABABABABABAB")!
        let replacementQuestID = UUID(uuidString: "CDCDCDCD-CDCD-CDCD-CDCD-CDCDCDCDCDCD")!
        let previousRequests = QuestNotificationPlanner.identifiers(for: previousQuestID).enumerated().map {
            index, identifier in
            makeScheduledRequest(
                identifier: identifier,
                fireDate: now.addingTimeInterval(Double(8 + index) * hour),
                title: "Previous title \(index)",
                body: "Previous body \(index)"
            )
        }
        let external = makeRequest(identifier: "external.notification")
        center.pendingRequestsList = previousRequests + [external]
        center.addErrorOnAttempt = 2

        let authorization = await service.reconcile(
            quests: [quest(id: replacementQuestID, deadlineOffset: 3 * hour)],
            now: now
        )

        #expect(authorization == .unavailable)
        #expect(Set(center.pendingRequestsList.map(\.identifier)) == Set((previousRequests + [external]).map(\.identifier)))
        for previous in previousRequests {
            let restored = center.pendingRequestsList.first { $0.identifier == previous.identifier }
            let previousTrigger = previous.trigger as? UNCalendarNotificationTrigger
            let restoredTrigger = restored?.trigger as? UNCalendarNotificationTrigger
            #expect(restoredTrigger?.dateComponents == previousTrigger?.dateComponents)
            #expect(restored?.content.title == previous.content.title)
            #expect(restored?.content.body == previous.content.body)
        }
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

        #expect(center.removedDeliveredIdentifiers == [identifiers + ReengagementReminderPlanner.allIdentifiers])
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

    @Test("editing a quest preserves its previous reminders when replacement fails")
    func syncRestoresPreviousQuestRequestsAfterReplacementFailure() async {
        let center = FakeQuestNotificationCenter(status: .authorized)
        let service = makeService(center: center)
        let questID = UUID(uuidString: "EFEFEFEF-EFEF-EFEF-EFEF-EFEFEFEFEFEF")!
        let previousRequests = QuestNotificationPlanner.identifiers(for: questID).enumerated().map {
            index, identifier in
            makeScheduledRequest(
                identifier: identifier,
                fireDate: now.addingTimeInterval(Double(8 + index) * hour),
                title: "Previous title \(index)",
                body: "Previous body \(index)"
            )
        }
        let external = makeRequest(identifier: "external.notification")
        center.pendingRequestsList = previousRequests + [external]
        center.addErrorOnAttempt = 2

        let authorization = await service.sync(
            quest: quest(id: questID, deadlineOffset: 3 * hour),
            now: now
        )

        #expect(authorization == .unavailable)
        #expect(Set(center.pendingRequestsList.map(\.identifier)) == Set((previousRequests + [external]).map(\.identifier)))
        for previous in previousRequests {
            let restored = center.pendingRequestsList.first { $0.identifier == previous.identifier }
            let previousTrigger = previous.trigger as? UNCalendarNotificationTrigger
            let restoredTrigger = restored?.trigger as? UNCalendarNotificationTrigger
            #expect(restoredTrigger?.dateComponents == previousTrigger?.dateComponents)
            #expect(restored?.content.title == previous.content.title)
            #expect(restored?.content.body == previous.content.body)
        }
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

    @Test("single-quest sync never requests undetermined notification permission")
    func editorSyncDoesNotPrompt() async {
        let center = FakeQuestNotificationCenter(status: .notDetermined)
        let service = makeService(center: center)

        let authorization = await service.sync(quest: quest(deadlineOffset: 3 * hour), now: now)

        #expect(authorization == .notDetermined)
        #expect(center.addedRequests.isEmpty)
        #expect(!center.events.contains("requestAuthorization"))
    }

    @Test("reconcile adds one repeating daily reengagement request beside deadline requests")
    func reconcileAddsDailyReengagementRequest() async {
        let center = FakeQuestNotificationCenter()
        let settings = ReengagementReminderSettings(
            isEnabled: true,
            minuteOfDay: 20 * 60,
            frequency: .daily,
            quietHours: nil,
            purpose: .finishOneQuest
        )
        let service = makeService(center: center, settings: settings)
        let questID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!

        await service.reconcile(quests: [quest(id: questID, deadlineOffset: 3 * hour)], now: now)

        let reminder = center.pendingRequestsList.first { $0.identifier == "reengagement.daily" }
        #expect(center.pendingRequestsList.map(\.identifier) == [
            QuestNotificationKind.dueSoon.identifier(for: questID),
            QuestNotificationKind.deadline.identifier(for: questID),
            "reengagement.daily",
        ])
        #expect((reminder?.trigger as? UNCalendarNotificationTrigger)?.repeats == true)
        #expect(reminder?.content.userInfo["questID"] as? String == questID.uuidString)
        #expect(reminder?.content.userInfo["kind"] as? String == ReengagementReminderPlanner.notificationKind)
    }

    @Test("weekday reminders reserve five slots before deadline planning")
    func weekdayRemindersReserveCapacity() async {
        let center = FakeQuestNotificationCenter()
        let settings = ReengagementReminderSettings(
            isEnabled: true,
            minuteOfDay: 20 * 60,
            frequency: .weekdays,
            quietHours: nil,
            purpose: .finishOneQuest
        )
        let service = makeService(center: center, settings: settings)
        let quests = (0..<QuestNotificationPlanner.maximumScheduledNotifications).map { index in
            quest(deadlineOffset: Double(2 + index) * hour)
        }

        await service.reconcile(quests: quests, now: now)

        let reminderIdentifiers = Set(ReengagementReminderPlanner.allIdentifiers)
        #expect(center.pendingRequestsList.count == QuestNotificationPlanner.maximumScheduledNotifications)
        #expect(center.pendingRequestsList.filter { reminderIdentifiers.contains($0.identifier) }.count == 5)
        #expect(center.pendingRequestsList.filter { $0.identifier.hasPrefix(QuestNotificationKind.identifierPrefix) }.count == 59)
    }

    @Test("repeated reconciliation replaces reengagement requests instead of duplicating them")
    func repeatedReconciliationDoesNotDuplicateReengagementRequests() async {
        let center = FakeQuestNotificationCenter()
        let settings = ReengagementReminderSettings(
            isEnabled: true,
            minuteOfDay: 20 * 60,
            frequency: .daily,
            quietHours: nil,
            purpose: .reviewPlan
        )
        let service = makeService(center: center, settings: settings)
        let questID = UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!
        let quests = [quest(id: questID, deadlineOffset: 3 * hour)]

        await service.reconcile(quests: quests, now: now)
        await service.reconcile(quests: quests, now: now.addingTimeInterval(60))

        #expect(center.pendingRequestsList.map(\.identifier) == [
            QuestNotificationKind.dueSoon.identifier(for: questID),
            QuestNotificationKind.deadline.identifier(for: questID),
            "reengagement.daily",
        ])
        #expect(center.removedPendingIdentifiers.contains { $0.contains("reengagement.daily") })
    }

    @Test("the shortcut path schedules the configured reminder a single-quest sync only reserves")
    func shortcutSyncSchedulesTheConfiguredReminder() async {
        let center = FakeQuestNotificationCenter()
        let service = makeService(center: center, settings: enabledDailyReminder)
        let questID = UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!
        let snapshot = quest(id: questID, deadlineOffset: 3 * hour).snapshot

        await service.syncWithoutRequestingAuthorization(snapshot: snapshot, now: now)
        // The capacity for it is already reserved at this point, but nothing plans it.
        #expect(!center.pendingRequestsList.contains { $0.identifier == "reengagement.daily" })

        await service.syncAndRefreshReengagement(snapshot: snapshot, readBoard: { [snapshot] }, now: now)

        #expect(center.pendingRequestsList.map(\.identifier) == [
            QuestNotificationKind.dueSoon.identifier(for: questID),
            QuestNotificationKind.deadline.identifier(for: questID),
            "reengagement.daily",
        ])
    }

    @Test("the shortcut path leaves the rest of the board's requests and delivered alerts alone")
    func shortcutSyncDoesNotDisturbTheRestOfTheBoard() async {
        let center = FakeQuestNotificationCenter()
        let service = makeService(center: center, settings: enabledDailyReminder)
        let existingID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let existingIdentifiers = QuestNotificationPlanner.identifiers(for: existingID)
        center.pendingRequestsList = existingIdentifiers.map {
            makeScheduledRequest(identifier: $0, fireDate: now.addingTimeInterval(10 * hour))
        }
        let created = quest(deadlineOffset: 3 * hour).snapshot

        await service.syncAndRefreshReengagement(
            snapshot: created,
            readBoard: { [created] },
            now: now
        )

        // This path can run with the app in the background, so pruning another quest's delivered
        // alert would clear a notification the user has not opened, and clearing its pending
        // requests would leave it unscheduled until the app is next launched.
        let pending = Set(center.pendingRequestsList.map(\.identifier))
        #expect(existingIdentifiers.allSatisfy { pending.contains($0) })
        #expect(center.removedPendingIdentifiers.allSatisfy { batch in
            existingIdentifiers.allSatisfy { !batch.contains($0) }
        })
        #expect(center.removedDeliveredIdentifiers.allSatisfy { batch in
            existingIdentifiers.allSatisfy { !batch.contains($0) }
        })
    }

    @Test("an unreadable board leaves the existing reengagement request in place")
    func unreadableBoardLeavesTheReminderAlone() async {
        let center = FakeQuestNotificationCenter()
        let service = makeService(center: center, settings: enabledDailyReminder)
        center.pendingRequestsList = [
            makeScheduledRequest(identifier: "reengagement.daily", fireDate: now.addingTimeInterval(8 * hour)),
        ]
        let created = quest(deadlineOffset: 3 * hour).snapshot

        await service.syncAndRefreshReengagement(snapshot: created, readBoard: { nil }, now: now)

        // Rewriting the reminder from a board that failed to load would aim it at a partial view.
        #expect(center.pendingRequestsList.contains { $0.identifier == "reengagement.daily" })
        #expect(!center.removedPendingIdentifiers.contains { $0.contains("reengagement.daily") })
    }

    @Test("a failed reminder add leaves the request that was already scheduled in place")
    func failedReminderAddKeepsTheExistingRequest() async {
        let center = FakeQuestNotificationCenter()
        let service = makeService(center: center, settings: enabledDailyReminder)
        let existing = makeScheduledRequest(
            identifier: "reengagement.daily",
            fireDate: now.addingTimeInterval(8 * hour)
        )
        center.pendingRequestsList = [existing]
        let created = quest(deadlineOffset: 3 * hour).snapshot
        // The two quest requests land first, so the reminder is the third add.
        center.addErrorOnAttempt = 3

        let authorization = await service.syncAndRefreshReengagement(
            snapshot: created,
            readBoard: { [created] },
            now: now
        ).authorization

        // Removing the reminder up front and only then failing to replace it would leave the user
        // with no reminder at all until the app is next opened.
        #expect(authorization == .unavailable)
        #expect(center.pendingRequestsList.contains { $0.identifier == "reengagement.daily" })
    }

    @Test("one failed weekday reminder does not abandon the remaining days")
    func oneFailedWeekdayAddDoesNotAbandonTheRest() async {
        let center = FakeQuestNotificationCenter()
        let settings = ReengagementReminderSettings(
            isEnabled: true,
            minuteOfDay: 20 * 60,
            frequency: .weekdays,
            quietHours: nil,
            purpose: .finishOneQuest
        )
        let service = makeService(center: center, settings: settings)
        let created = quest(deadlineOffset: 3 * hour).snapshot
        // The two quest requests go first, so the reminders are attempts 3 through 7.
        center.addErrorOnAttempt = 3

        let authorization = await service.syncAndRefreshReengagement(
            snapshot: created,
            readBoard: { [created] },
            now: now
        ).authorization

        let scheduled = Set(center.pendingRequestsList.map(\.identifier))
        let reminders = ReengagementReminderPlanner.allIdentifiers.filter { scheduled.contains($0) }
        #expect(authorization == .unavailable)
        #expect(reminders.count == 4)
    }

    @Test("reminders left over from an older frequency are freed before the quest requests are added")
    func obsoleteRemindersArePrunedBeforeTheQuestAdds() async {
        let center = FakeQuestNotificationCenter()
        // Stored settings say daily; five weekday requests from the previous frequency are still
        // pending because their reconcile has not run. `performSync` reserves one slot, not five.
        let service = makeService(center: center, settings: enabledDailyReminder)
        center.pendingRequestsList = (2...6).map { weekday in
            makeScheduledRequest(
                identifier: "reengagement.weekday.\(weekday)",
                fireDate: now.addingTimeInterval(Double(weekday) * hour)
            )
        }
        let created = quest(deadlineOffset: 3 * hour).snapshot

        await service.syncAndRefreshReengagement(snapshot: created, readBoard: { [created] }, now: now)

        let freed = center.events.firstIndex {
            $0.hasPrefix("removePending:") && $0.contains("reengagement.weekday")
        }
        let firstQuestAdd = center.events.firstIndex {
            $0.hasPrefix("add:\(QuestNotificationKind.identifierPrefix)")
        }
        #expect(freed != nil)
        #expect(firstQuestAdd != nil)
        // Freeing them afterwards would let the platform drop a quest request at the limit and
        // then release the slots it needed, with no error reported anywhere.
        #expect((freed ?? .max) < (firstQuestAdd ?? 0))
        #expect(center.pendingRequestsList.contains { $0.identifier == "reengagement.daily" })
        #expect(!center.pendingRequestsList.contains { $0.identifier.hasPrefix("reengagement.weekday") })
    }

    @Test("overlapping shortcut refreshes do not read the board before each other's writes")
    func overlappingRefreshesSerializeTheBoardRead() async {
        let center = FakeQuestNotificationCenter()
        let service = makeService(center: center, settings: enabledDailyReminder)
        let first = quest(deadlineOffset: 3 * hour).snapshot
        let second = quest(deadlineOffset: 2 * hour).snapshot

        async let firstRefresh = service.syncAndRefreshReengagement(
            snapshot: first,
            readBoard: { center.events.append("read"); return [first] },
            now: now
        )
        async let secondRefresh = service.syncAndRefreshReengagement(
            snapshot: second,
            readBoard: { center.events.append("read"); return [first, second] },
            now: now
        )
        _ = await (firstRefresh, secondRefresh)

        // Reading outside the queue lets both reads land first, and the later refresh then writes a
        // reminder planned from the older board. Serialized, every read is followed by its own
        // writes before the next one begins.
        let reads = center.events.indices.filter { center.events[$0] == "read" }
        #expect(reads.count == 2)
        #expect(center.events[(reads[0] + 1)..<reads[1]].contains { $0.hasPrefix("add:") })
    }

    private var enabledDailyReminder: ReengagementReminderSettings {
        ReengagementReminderSettings(
            isEnabled: true,
            minuteOfDay: 20 * 60,
            frequency: .daily,
            quietHours: nil,
            purpose: .finishOneQuest
        )
    }

    private func makeRequest(identifier: String) -> UNNotificationRequest {
        UNNotificationRequest(identifier: identifier, content: UNMutableNotificationContent(), trigger: nil)
    }

    private func makeScheduledRequest(
        identifier: String,
        fireDate: Date,
        title: String = "",
        body: String = ""
    ) -> UNNotificationRequest {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(
            [.timeZone, .year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        return UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
    }

    // These two work off `Date.now`, not the suite's fixed `now`. A non-repeating
    // `UNCalendarNotificationTrigger` whose date has passed returns nil from `nextTriggerDate()`,
    // so against the 2023 fixture every seeded request vanishes from the pending set and the cap
    // has nothing to act on — a green that proves nothing. Real future dates keep them visible.
    @Test("the cap counts the reminders actually pending, not the ones the settings ask for")
    func capCountsPendingRemindersNotConfiguredOnes() async {
        let center = FakeQuestNotificationCenter()
        // Settings say daily, so the old reservation would free 63 slots for quests. Five weekday
        // requests from the previous frequency are still pending, which makes the real ceiling 59.
        let service = makeService(center: center, settings: enabledDailyReminder)
        let cap = QuestNotificationPlanner.maximumScheduledNotifications
        let base = Date.now
        let staleReminders = (2...6).map { weekday in
            makeScheduledRequest(
                identifier: "reengagement.weekday.\(weekday)",
                fireDate: base.addingTimeInterval(Double(weekday) * hour)
            )
        }
        let questRequests = (0..<(cap - staleReminders.count)).map { index in
            makeScheduledRequest(
                identifier: QuestNotificationKind.deadline.identifier(for: UUID()),
                fireDate: base.addingTimeInterval(Double(100 + index) * hour)
            )
        }
        center.pendingRequestsList = staleReminders + questRequests

        await service.sync(
            quest: Quest(title: "빨래", deadline: base.addingTimeInterval(3 * hour), importance: .medium),
            now: base
        )

        // Reserving only the configured single slot would admit past the platform limit, and
        // `UNUserNotificationCenter` resolves that overflow itself, silently.
        #expect(center.pendingRequestsList.count <= cap)
        #expect(!center.events.contains { $0.hasPrefix("droppedByPlatform:") })
        #expect(staleReminders.allSatisfy { stale in
            center.pendingRequestsList.contains { $0.identifier == stale.identifier }
        })
    }

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

    @Test("a later-firing quest loses to the incumbents instead of displacing them")
    func syncDoesNotEvictNearerRemindersForAFartherQuest() async {
        let center = FakeQuestNotificationCenter()
        let service = makeService(center: center)
        let cap = QuestNotificationPlanner.maximumScheduledNotifications
        let base = Date.now

        // Every slot taken by reminders that all fire sooner than the quest being synced.
        let seeded = (0..<cap).map { index in
            makeScheduledRequest(
                identifier: QuestNotificationKind.deadline.identifier(for: UUID()),
                fireDate: base.addingTimeInterval(Double(1 + index) * hour)
            )
        }
        center.pendingRequestsList = seeded

        let questID = UUID(uuidString: "88888888-8888-8888-8888-888888888888")!
        let farQuest = Quest(
            id: questID,
            title: "빨래",
            deadline: base.addingTimeInterval(500 * hour),
            importance: .medium
        )
        await service.sync(quest: farQuest, now: base)

        let remaining = center.pendingRequestsList.map(\.identifier)
        // Freeing a slot per incoming plan would have dropped the two nearest-to-the-limit
        // incumbents for a quest due three weeks later. Soonest-first means the newcomer waits.
        #expect(remaining.count == cap)
        #expect(remaining == seeded.map(\.identifier))
        #expect(!remaining.contains(QuestNotificationKind.dueSoon.identifier(for: questID)))
        #expect(!remaining.contains(QuestNotificationKind.deadline.identifier(for: questID)))
    }

    @Test("a failed add puts back the reminders the cap evicted for it")
    func failedAddRestoresEvictedReminders() async {
        let center = FakeQuestNotificationCenter()
        let service = makeService(center: center)
        let cap = QuestNotificationPlanner.maximumScheduledNotifications
        let base = Date.now

        let seeded = (0..<cap).map { index in
            makeScheduledRequest(
                identifier: QuestNotificationKind.deadline.identifier(for: UUID()),
                fireDate: base.addingTimeInterval(Double(100 + index) * hour)
            )
        }
        center.pendingRequestsList = seeded
        // Fails the first add, which is the one the eviction was payment for.
        center.addErrorOnAttempt = 1

        let nearQuest = Quest(
            id: UUID(),
            title: "빨래",
            deadline: base.addingTimeInterval(3 * hour),
            importance: .medium
        )
        await service.sync(quest: nearQuest, now: base)

        // The two furthest were evicted to make room; the add never landed, so they must be back.
        let remaining = Set(center.pendingRequestsList.map(\.identifier))
        #expect(remaining.contains(seeded[cap - 1].identifier))
        #expect(remaining.contains(seeded[cap - 2].identifier))
        #expect(remaining.count == cap)
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

    /// Models the platform's own limit: `UNUserNotificationCenter` keeps a bounded number of pending
    /// requests and resolves an overflow itself, silently and without erroring. Dropping the add is
    /// the pessimistic reading of that, and it is what makes the difference between evicting before
    /// and after the add observable — an unbounded fake reports success for both.
    func add(_ request: UNNotificationRequest) async throws {
        addAttemptCount += 1
        if addErrorOnAttempt == addAttemptCount { throw FakeNotificationError.addFailed }
        if let addError { throw addError }
        events.append("add:\(request.identifier)")
        addedRequests.append(request)
        // `UNUserNotificationCenter` drops a pending request that shares an identifier and keeps
        // the new one. A fake that appends instead reports a duplicate where the platform has a
        // replacement, and it hides whether a failed add left the previous request intact.
        if let existing = pendingRequestsList.firstIndex(where: { $0.identifier == request.identifier }) {
            pendingRequestsList[existing] = request
            return
        }
        guard pendingRequestsList.count < QuestNotificationPlanner.maximumScheduledNotifications else {
            events.append("droppedByPlatform:\(request.identifier)")
            return
        }
        pendingRequestsList.append(request)
    }

    func pendingNotificationRequests() async -> [RestorableNotificationRequest] {
        pendingRequestsList.map { RestorableNotificationRequest(request: $0) }
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
