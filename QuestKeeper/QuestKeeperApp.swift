//
//  QuestKeeperApp.swift
//  QuestKeeper
//
//  Created by Dongmin yu on 7/8/26.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct QuestKeeperApp: App {
    @State private var notificationRouteStore: NotificationRouteStore
    private let notificationDelegate: NotificationDelegate

    init() {
        let routeStore = NotificationRouteStore()
        let delegate = NotificationDelegate(routeStore: routeStore)
        _notificationRouteStore = State(initialValue: routeStore)
        notificationDelegate = delegate
        UNUserNotificationCenter.current().delegate = delegate
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Quest.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(notificationRouteStore: notificationRouteStore)
        }
        .modelContainer(sharedModelContainer)
    }
}
