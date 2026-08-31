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
        let userInfo = response.notification.request.content.userInfo
        let questIDString = NotificationRouteStore.questIDString(from: userInfo)
        let isReengagement = NotificationRouteStore.isReengagement(userInfo: userInfo)
        await routeStore.route(questIDString: questIDString, isReengagement: isReengagement)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
