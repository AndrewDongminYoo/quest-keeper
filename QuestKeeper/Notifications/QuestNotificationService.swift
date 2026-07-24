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

enum QuestNotificationAuthorization: Equatable, Sendable {
    case notDetermined
    case allowed
    case denied
    case unavailable

    var canSchedule: Bool { self == .allowed }
}

@MainActor
protocol QuestNotificationCenter: AnyObject {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func pendingNotificationIdentifiers() async -> [String]
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

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}

@MainActor
final class QuestNotificationService {
    static let shared = QuestNotificationService()

    private let center: QuestNotificationCenter
    private let calendar: Calendar
    private var operationTail: Task<Void, Never>?
    private var operationVersion = 0

    init(center: QuestNotificationCenter = SystemQuestNotificationCenter(), calendar: Calendar = .current) {
        self.center = center
        self.calendar = calendar
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
    func sync(quest: Quest, now: Date) async -> QuestNotificationAuthorization {
        let questID = quest.id
        let snapshot = quest.snapshot

        return await enqueue {
            await self.performSync(questID: questID, snapshot: snapshot, now: now)
        }
    }

    func cancel(questID: UUID) async {
        await enqueue {
            self.performCancel(questID: questID)
        }
    }

    @discardableResult
    func reconcile(quests: [Quest], now: Date) async -> QuestNotificationAuthorization {
        let plans = quests.flatMap { quest in
            QuestNotificationPlanner.plans(for: quest.snapshot, now: now)
        }
        let deliveredIdentifiersToRemove = quests.flatMap { quest in
            QuestNotificationPlanner.identifiers(for: quest.id)
        }

        return await enqueue {
            await self.performReconcile(
                plans: plans,
                deliveredIdentifiersToRemove: deliveredIdentifiersToRemove
            )
        }
    }

    private func performSync(
        questID: UUID,
        snapshot: QuestSnapshot,
        now: Date
    ) async -> QuestNotificationAuthorization {
        let identifiers = QuestNotificationPlanner.identifiers(for: questID)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)

        let plans = QuestNotificationPlanner.plans(for: snapshot, now: now)
        guard !plans.isEmpty else { return await authorizationStatus() }

        let authorization = await requestAuthorizationIfNeeded()
        guard authorization.canSchedule else { return authorization }

        for plan in plans {
            do {
                try await center.add(request(for: plan))
            } catch {
                return .unavailable
            }
        }

        return authorization
    }

    private func performCancel(questID: UUID) {
        let identifiers = QuestNotificationPlanner.identifiers(for: questID)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private func performReconcile(
        plans: [QuestNotificationPlan],
        deliveredIdentifiersToRemove: [String]
    ) async -> QuestNotificationAuthorization {
        let pendingIdentifiers = await center.pendingNotificationIdentifiers()
        let questKeeperIdentifiers = pendingIdentifiers
            .filter { QuestNotificationPlanner.isQuestNotificationIdentifier($0) }

        if !questKeeperIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: questKeeperIdentifiers)
        }
        if !deliveredIdentifiersToRemove.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: deliveredIdentifiersToRemove)
        }

        let authorization = await authorizationStatus()
        guard !plans.isEmpty else { return authorization }
        guard authorization.canSchedule else { return authorization }

        for plan in plans {
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
