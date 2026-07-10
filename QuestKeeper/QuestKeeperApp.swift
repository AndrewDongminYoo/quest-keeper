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
    @Environment(\.scenePhase) private var scenePhase
    @State private var notificationRouteStore: NotificationRouteStore
    /// Recreated on a real foreground-from-background so `@Query` re-reads from a fresh connection.
    @State private var sharedModelContainer: ModelContainer
    /// True once we've actually been backgrounded — gates the container swap so a mere Control
    /// Center / notification-banner peek (`.inactive` → `.active`, never `.background`) doesn't refresh.
    @State private var didBackground = false
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
        do {
            _sharedModelContainer = State(initialValue: try QuestModelContainer.make())
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                notificationRouteStore: notificationRouteStore,
                widgetSnapshotWriter: widgetSnapshotWriter
            )
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, phase in
            // A warm foreground's `@Query` keeps its own SQLite snapshot and never sees writes the
            // widget process committed while we were backgrounded — and `rollback()` reuses that same
            // connection, so it doesn't help. Swapping in a fresh container opens a new connection that
            // reads the on-disk truth, the way a cold launch already does (verified via spike 009).
            // Only after a genuine `.background` (where the widget could have written) — not on a
            // Control Center peek — so we don't needlessly refresh or tear down an open editor sheet.
            switch phase {
            case .background:
                didBackground = true
            case .active where didBackground:
                didBackground = false
                if let refreshed = try? QuestModelContainer.make() {
                    sharedModelContainer = refreshed
                }
            default:
                break
            }
        }
    }
}
