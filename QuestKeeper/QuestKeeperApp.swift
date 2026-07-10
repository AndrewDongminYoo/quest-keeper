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
    private let widgetSnapshotWriter: WidgetDungeonSnapshotWriter

    init() {
        let routeStore = NotificationRouteStore()
        let snapshotWriter = WidgetDungeonSnapshotWriter()
        let delegate = NotificationDelegate(routeStore: routeStore)
        _notificationRouteStore = State(initialValue: routeStore)
        notificationDelegate = delegate
        widgetSnapshotWriter = snapshotWriter
        UNUserNotificationCenter.current().delegate = delegate
    }

    var sharedModelContainer: ModelContainer = {
        do {
            return try QuestModelContainer.make()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(
                notificationRouteStore: notificationRouteStore,
                widgetSnapshotWriter: widgetSnapshotWriter
            )
        }
        .modelContainer(sharedModelContainer)
    }
}
