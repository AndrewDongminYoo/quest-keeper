//
//  NotificationDelegate.swift
//  QuestKeeper
//
//  Phase 3 — bridge UserNotifications responses into SwiftUI route state.
//

import UserNotifications

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let routeStore: NotificationRouteStore

    @MainActor
    init(routeStore: NotificationRouteStore) {
        self.routeStore = routeStore
        super.init()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let questIDString = NotificationRouteStore.questIDString(
            from: response.notification.request.content.userInfo
        )
        await routeStore.route(questIDString: questIDString)
        guard let questIDString, let questID = UUID(uuidString: questIDString) else { return }
        let identifier = response.notification.request.identifier
        let kind = QuestNotificationKind.allCases.first(where: { identifier.hasSuffix(".\($0.rawValue)") })
        let questKey = await AnalyticsRecorder.shared.questKey(for: questID)
        await AnalyticsRecorder.shared.record(AnalyticsEvent(name: .notificationOpened, properties: [
            "quest_key": .string(questKey),
            "notification_kind": .string(kind?.rawValue ?? "unknown"),
            "destination": "quest"
        ]))
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
