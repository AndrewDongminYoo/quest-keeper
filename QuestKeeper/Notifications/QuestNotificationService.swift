//
//  QuestNotificationService.swift
//  QuestKeeper
//
//  Phase 3 — UserNotifications side effects. Game truth remains derived from facts.
//

import Foundation
import os
import UserNotifications

private let notificationLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "QuestKeeper",
    category: "QuestNotificationService"
)

nonisolated enum QuestNotificationAuthorization: Equatable, Sendable {
    case notDetermined
    case allowed
    case denied
    case unavailable

    var canSchedule: Bool { self == .allowed }
}

nonisolated enum QuestNotificationPermissionAction: Equatable, Sendable {
    case requestAuthorization
    case openSettings

    static func make(
        authorization: QuestNotificationAuthorization?
    ) -> QuestNotificationPermissionAction? {
        switch authorization {
        case .notDetermined:
            return .requestAuthorization
        case .denied:
            return .openSettings
        case .allowed, .unavailable, nil:
            return nil
        }
    }
}

/// A scheduled request reduced to what the cap needs to choose survivors.
nonisolated struct PendingQuestNotification: Equatable, Sendable {
    let identifier: String
    let fireDate: Date
}

@MainActor
protocol QuestNotificationCenter: AnyObject {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func pendingNotificationIdentifiers() async -> [String]
    func pendingQuestNotifications() async -> [PendingQuestNotification]
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func removeDeliveredNotifications(withIdentifiers identifiers: [String])
}

@MainActor
final class SystemQuestNotificationCenter: QuestNotificationCenter {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            center.requestAuthorization(options: options) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func pendingNotificationIdentifiers() async -> [String] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests.map(\.identifier))
            }
        }
    }

    func pendingQuestNotifications() async -> [PendingQuestNotification] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests.compactMap { request in
                    guard let trigger = request.trigger as? UNCalendarNotificationTrigger,
                          let fireDate = trigger.nextTriggerDate() else { return nil }
                    return PendingQuestNotification(identifier: request.identifier, fireDate: fireDate)
                })
            }
        }
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}

@MainActor
final class QuestNotificationService {
    private enum AuthorizationRequestPolicy {
        case ifNeeded
        case never
    }

    static let shared = QuestNotificationService()

    private let center: QuestNotificationCenter
    private let calendar: Calendar
    private let reengagementSettingsStore: ReengagementReminderSettingsStore
    private var operationTail: Task<Void, Never>?
    private var operationVersion = 0

    init(
        center: QuestNotificationCenter = SystemQuestNotificationCenter(),
        // `.current`는 초기화 시점의 시간대를 스냅샷으로 굳힌다. `shared`는 앱 수명 내내 살아 있어서,
        // 여행으로 시간대가 바뀌면 반복 재방문 트리거가 옛 지역의 20:00에 고정된다.
        calendar: Calendar = .autoupdatingCurrent,
        reengagementSettingsStore: ReengagementReminderSettingsStore = .shared
    ) {
        self.center = center
        self.calendar = calendar
        self.reengagementSettingsStore = reengagementSettingsStore
    }

    func authorizationStatus() async -> QuestNotificationAuthorization {
        await Self.mapAuthorizationStatus(center.authorizationStatus())
    }

    func requestAuthorizationIfNeeded() async -> QuestNotificationAuthorization {
        let status = await center.authorizationStatus()
        switch status {
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound]) ? .allowed : .denied
            } catch {
                return .unavailable
            }
        default:
            return Self.mapAuthorizationStatus(status)
        }
    }

    @discardableResult
    func sync(quest: Quest, now: Date, locale: Locale = .current) async -> QuestNotificationAuthorization {
        await sync(
            questID: quest.id,
            snapshot: quest.snapshot,
            now: now,
            locale: locale,
            authorizationRequestPolicy: .never
        )
    }

    @discardableResult
    func syncWithoutRequestingAuthorization(
        snapshot: QuestSnapshot,
        now: Date,
        locale: Locale = .current
    ) async -> QuestNotificationAuthorization {
        await sync(
            questID: snapshot.id,
            snapshot: snapshot,
            now: now,
            locale: locale,
            authorizationRequestPolicy: .never
        )
    }

    func cancel(questID: UUID) async {
        await enqueue {
            self.performCancel(questID: questID)
        }
    }

    @discardableResult
    func reconcile(quests: [Quest], now: Date, locale: Locale = .current) async -> QuestNotificationAuthorization {
        await reconcile(
            quests: quests,
            now: now,
            locale: locale,
            authorizationRequestPolicy: .never
        )
    }

    /// The background-safe half of a reconcile, for `CreateQuestIntent`.
    ///
    /// A single-quest sync subtracts the configured reengagement requests from its capacity but
    /// never plans them; only a reconcile does. The shortcut path runs without an app activation,
    /// so nothing reconciles afterwards and the reminder stays unscheduled. Running a full
    /// `reconcile` here would fix that and break two other things: it prunes the whole board's
    /// *delivered* alerts, which from the background would silently clear notifications the user
    /// has not opened, and it clears every pending request before re-adding, so one failed `add`
    /// would leave the rest of the board unscheduled until the app is next opened.
    ///
    /// So sync the created quest through the same capacity-reserving path the app uses, then
    /// rewrite only the reengagement requests. `board` is the whole quest set, which the
    /// reengagement planner needs to choose its target; pass `nil` when it could not be read, and
    /// the existing reengagement requests are left alone rather than rewritten from a partial view.
    @discardableResult
    func syncAndRefreshReengagement(
        snapshot: QuestSnapshot,
        board: [QuestSnapshot]?,
        now: Date,
        locale: Locale = .current
    ) async -> QuestNotificationAuthorization {
        // One enqueue, not two. Releasing the queue between the sync and the refresh would let a
        // second shortcut creation interleave, and the later refresh could then write a reminder
        // planned from the older `board`.
        await enqueue {
            let authorization = await self.performSync(
                questID: snapshot.id,
                snapshot: snapshot,
                now: now,
                locale: locale,
                authorizationRequestPolicy: .never
            )
            guard let board, authorization.canSchedule else { return authorization }

            return await self.performReengagementRefresh(
                plans: ReengagementReminderPlanner.plans(
                    for: board,
                    settings: self.reengagementSettingsStore.load(),
                    now: now,
                    calendar: self.calendar,
                    locale: locale
                ),
                authorization: authorization
            )
        }
    }

    @discardableResult
    func requestAuthorizationAndReconcile(
        quests: [Quest],
        now: Date,
        locale: Locale = .current
    ) async -> QuestNotificationAuthorization {
        await reconcile(
            quests: quests,
            now: now,
            locale: locale,
            authorizationRequestPolicy: .ifNeeded
        )
    }

    private func reconcile(
        quests: [Quest],
        now: Date,
        locale: Locale,
        authorizationRequestPolicy: AuthorizationRequestPolicy
    ) async -> QuestNotificationAuthorization {
        let settings = reengagementSettingsStore.load()
        let snapshots = quests.map(\.snapshot)
        let reengagementPlans = ReengagementReminderPlanner.plans(
            for: snapshots,
            settings: settings,
            now: now,
            calendar: calendar,
            locale: locale
        )
        let plans = QuestNotificationPlanner.plans(
            for: snapshots,
            now: now,
            maximumCount: QuestNotificationPlanner.maximumScheduledNotifications - reengagementPlans.count,
            locale: locale
        )
        let deliveredIdentifiersToRemove = quests.flatMap { quest in
            QuestNotificationPlanner.identifiers(for: quest.id)
        } + ReengagementReminderPlanner.allIdentifiers

        return await enqueue {
            await self.performReconcile(
                plans: plans,
                reengagementPlans: reengagementPlans,
                deliveredIdentifiersToRemove: deliveredIdentifiersToRemove,
                authorizationRequestPolicy: authorizationRequestPolicy
            )
        }
    }

    private func performSync(
        questID: UUID,
        snapshot: QuestSnapshot,
        now: Date,
        locale: Locale,
        authorizationRequestPolicy: AuthorizationRequestPolicy
    ) async -> QuestNotificationAuthorization {
        let identifiers = QuestNotificationPlanner.identifiers(for: questID)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)

        let plans = QuestNotificationPlanner.plans(for: snapshot, now: now, locale: locale)
        guard !plans.isEmpty else { return await authorizationStatus() }

        let authorization = switch authorizationRequestPolicy {
        case .ifNeeded:
            await requestAuthorizationIfNeeded()
        case .never:
            await authorizationStatus()
        }
        guard authorization.canSchedule else { return authorization }

        let capacity = QuestNotificationPlanner.maximumScheduledNotifications
            - reengagementSettingsStore.load().scheduledRequestCount
        let (admitted, evicted) = await admit(plans, capacity: capacity, locale: locale)
        for plan in admitted {
            do {
                try await center.add(request(for: plan))
            } catch {
                // The eviction above was payment for an add that then did not happen, and it was
                // taken from *other* quests — leaving it would silently drop their reminders until
                // the next full reconcile. Put them back before reporting the failure.
                performCancel(questID: questID)
                await restore(evicted)
                return .unavailable
            }
        }

        return authorization
    }

    private func restore(_ plans: [QuestNotificationPlan]) async {
        for plan in plans {
            try? await center.add(request(for: plan))
        }
    }

    /// `performReconcile` bounds the set it writes, but a single-quest sync adds on top of whatever
    /// is already scheduled — so once a full board has filled the platform's slots, creating or
    /// retrying one quest would push past the limit and hand the choice of what to drop back to the
    /// unspecified behaviour the cap exists to avoid.
    ///
    /// The eviction has to happen *before* the adds, not after. The platform applies its own limit
    /// as each request is submitted, so by the time an add has overflowed, its choice is already
    /// made and a later query just reports a set that is back at the limit — nothing left to evict
    /// and the wrong requests already gone. Freeing the slots first is what makes "soonest wins"
    /// hold regardless of how the platform resolves an overflow, because it never sees one.
    ///
    /// Both sides go into one ordering. Freeing a slot per incoming plan would let a quest due next
    /// month evict reminders due tomorrow — soonest-first has to decide between the incoming and the
    /// incumbent, not assume the newcomer wins. Returns the plans that earned a slot; the rest are
    /// simply not scheduled, and the next reconcile reconsiders them once they are near enough.
    private func admit(
        _ plans: [QuestNotificationPlan],
        capacity: Int,
        locale: Locale
    ) async -> (admitted: [QuestNotificationPlan], evicted: [QuestNotificationPlan]) {
        let cap = max(0, capacity)
        let pending = await center.pendingQuestNotifications()
            .filter { QuestNotificationPlanner.isQuestNotificationIdentifier($0.identifier) }
        guard pending.count + plans.count > cap else { return (plans, []) }

        let candidates = pending + plans.map {
            PendingQuestNotification(identifier: $0.identifier, fireDate: $0.fireDate)
        }
        let survivors = Set(
            candidates
                .sorted { firesEarlier($0, $1) }
                .prefix(cap)
                .map(\.identifier)
        )

        let evicted = pending.filter { !survivors.contains($0.identifier) }
        if !evicted.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: evicted.map(\.identifier))
        }
        return (
            plans.filter { survivors.contains($0.identifier) },
            evicted.compactMap { QuestNotificationPlanner.plan(restoring: $0, locale: locale) }
        )
    }

    /// The planner's order, with the same identifier tiebreak so the survivor set is deterministic.
    private func firesEarlier(_ lhs: PendingQuestNotification, _ rhs: PendingQuestNotification) -> Bool {
        if lhs.fireDate != rhs.fireDate {
            return lhs.fireDate < rhs.fireDate
        }
        return lhs.identifier < rhs.identifier
    }

    private func sync(
        questID: UUID,
        snapshot: QuestSnapshot,
        now: Date,
        locale: Locale,
        authorizationRequestPolicy: AuthorizationRequestPolicy
    ) async -> QuestNotificationAuthorization {
        await enqueue {
            await self.performSync(
                questID: questID,
                snapshot: snapshot,
                now: now,
                locale: locale,
                authorizationRequestPolicy: authorizationRequestPolicy
            )
        }
    }

    /// Scoped to the reengagement identifiers alone: it touches no quest request and removes no
    /// delivered notification, so a background caller cannot disturb the rest of the board.
    ///
    /// Only the *obsolete* identifiers are removed first — the ones the new plan set does not
    /// cover, which is how a daily reminder's leftover request disappears after a switch to
    /// weekdays. The identifiers the plan does cover are replaced by the add itself, since
    /// `UNUserNotificationCenter` drops a pending request that shares an identifier. Removing them
    /// up front instead would leave a working reminder deleted whenever an `add` then failed.
    ///
    /// An obsolete request is dropped even when the replacing adds then fail, and that is
    /// deliberate: it is obsolete because the stored settings no longer describe it, so keeping it
    /// alive would fire at a cadence the user has switched off. Preservation applies to the
    /// reminder the settings still ask for, not to one they have retired.
    ///
    /// An empty plan set therefore clears everything, which is intended: the planner returns
    /// nothing when reminders are off or no quest is pending, and a reminder pointing at a
    /// resolved quest is worse than none.
    private func performReengagementRefresh(
        plans: [ReengagementReminderPlan],
        authorization: QuestNotificationAuthorization
    ) async -> QuestNotificationAuthorization {
        let planned = Set(plans.map(\.identifier))
        let obsolete = await center.pendingNotificationIdentifiers().filter {
            ReengagementReminderPlanner.isReengagementNotificationIdentifier($0)
                && !planned.contains($0)
        }
        if !obsolete.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: obsolete)
        }

        // Weekday reminders are five independent requests, and this path can be the last thing to
        // run before a long gap with no activation. Abandoning the rest on the first failure would
        // leave those days silent, or still aimed at whichever quest the previous refresh chose.
        var anyAddFailed = false
        for plan in plans {
            do {
                try await center.add(request(for: plan))
            } catch {
                anyAddFailed = true
            }
        }
        return anyAddFailed ? .unavailable : authorization
    }

    private func performCancel(questID: UUID) {
        let identifiers = QuestNotificationPlanner.identifiers(for: questID)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private func performReconcile(
        plans: [QuestNotificationPlan],
        reengagementPlans: [ReengagementReminderPlan],
        deliveredIdentifiersToRemove: [String],
        authorizationRequestPolicy: AuthorizationRequestPolicy
    ) async -> QuestNotificationAuthorization {
        let pendingIdentifiers = await center.pendingNotificationIdentifiers()
        let questKeeperIdentifiers = pendingIdentifiers
            .filter {
                QuestNotificationPlanner.isQuestNotificationIdentifier($0)
                    || ReengagementReminderPlanner.isReengagementNotificationIdentifier($0)
            }

        if !questKeeperIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: questKeeperIdentifiers)
        }
        if !deliveredIdentifiersToRemove.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: deliveredIdentifiersToRemove)
        }

        let authorization = switch authorizationRequestPolicy {
        case .ifNeeded:
            await requestAuthorizationIfNeeded()
        case .never:
            await authorizationStatus()
        }
        guard !plans.isEmpty || !reengagementPlans.isEmpty else { return authorization }
        guard authorization.canSchedule else { return authorization }

        for plan in plans {
            do {
                try await center.add(request(for: plan))
            } catch {
                return .unavailable
            }
        }
        for plan in reengagementPlans {
            do {
                try await center.add(request(for: plan))
            } catch {
                return .unavailable
            }
        }

        return authorization
    }

    @discardableResult
    private func enqueue<T: Sendable>(_ operation: @escaping @MainActor () async -> T) async -> T {
        let previous = operationTail
        operationVersion += 1
        let version = operationVersion
        let task = Task { @MainActor in
            await previous?.value
            return await operation()
        }
        operationTail = Task { @MainActor in
            _ = await task.value
        }
        let result = await task.value
        if operationVersion == version {
            operationTail = nil
        }
        return result
    }

    private func request(for plan: QuestNotificationPlan) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = plan.title
        content.body = plan.body
        content.sound = .default
        content.userInfo = [
            "questID": plan.questID.uuidString,
            "kind": plan.kind.rawValue,
        ]

        let components = calendar.dateComponents(
            [.timeZone, .year, .month, .day, .hour, .minute, .second],
            from: plan.fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: plan.identifier, content: content, trigger: trigger)
    }

    private func request(for plan: ReengagementReminderPlan) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = plan.title
        content.body = plan.body
        content.sound = .default
        content.userInfo = [
            "questID": plan.questID.uuidString,
            "kind": ReengagementReminderPlanner.notificationKind,
        ]

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: plan.dateComponents,
            repeats: plan.repeats
        )
        return UNNotificationRequest(identifier: plan.identifier, content: content, trigger: trigger)
    }

    private static func mapAuthorizationStatus(_ status: UNAuthorizationStatus) -> QuestNotificationAuthorization {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized, .provisional, .ephemeral:
            return .allowed
        @unknown default:
            notificationLogger.error("Unknown notification authorization status: \(status.rawValue)")
            return .unavailable
        }
    }
}
