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
    @State private var hasRecordedRetentionActivation = false
    @State private var retentionActivationSessionID = UUID()
    private let notificationDelegate: NotificationDelegate
    private let widgetSnapshotWriter: WidgetDungeonSnapshotWriter
    private let retentionBaselineWriter: RetentionBaselineWriter

    init() {
        let routeStore = NotificationRouteStore()
        let snapshotWriter = WidgetDungeonSnapshotWriter()
        let delegate = NotificationDelegate(routeStore: routeStore)
        _notificationRouteStore = State(initialValue: routeStore)
        notificationDelegate = delegate
        widgetSnapshotWriter = snapshotWriter
        retentionBaselineWriter = RetentionBaselineWriter()
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
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .background:
                didBackground = true
                retentionActivationSessionID = UUID()
            case .active:
                // A warm foreground's `@Query` keeps its own SQLite snapshot and never sees writes the
                // widget process committed while we were backgrounded — and `rollback()` reuses that
                // same connection, so it doesn't help. Swapping in a fresh container opens a new
                // connection that reads the on-disk truth, like a cold launch (verified via spike 009).
                // Only after a genuine `.background` (where the widget could have written) — not a
                // Control Center peek — so we don't needlessly refresh or tear down an open editor.
                let wasBackgrounded = didBackground
                let container: ModelContainer
                if didBackground, let refreshed = try? QuestModelContainer.make() {
                    didBackground = false
                    sharedModelContainer = refreshed
                    container = refreshed
                } else {
                    container = sharedModelContainer
                }
                if shouldRecordRetentionActivation(
                    hasRecordedActivation: hasRecordedRetentionActivation,
                    didBackground: wasBackgrounded
                ) {
                    hasRecordedRetentionActivation = true
                    retentionBaselineWriter.recordActivationAndWrite(
                        sessionID: retentionActivationSessionID,
                        at: .now,
                        using: container
                    )
                }
                syncActivation(using: container)
            default:
                break
            }
        }
    }

    /// Reconcile notifications and rewrite the widget snapshot from the *current* (freshly swapped)
    /// container. This runs here — not in `ContentView.onBecameActive` — because a warm foreground's
    /// `@Query` is stale, and opening a second container for the same store to read fresh would trap
    /// in SwiftData. Using the one live container avoids both the staleness and the trap.
    private func syncActivation(using container: ModelContainer) {
        let writer = widgetSnapshotWriter
        Task { @MainActor in
            guard let quests = try? container.mainContext.fetch(
                FetchDescriptor<Quest>(sortBy: [SortDescriptor(\.deadline)])
            ) else { return }
            _ = await QuestNotificationService.shared.reconcile(quests: quests, now: .now)
            await writer.submit(WidgetDungeonPayload.make(from: quests))
        }
    }
}

nonisolated func shouldRecordRetentionActivation(
    hasRecordedActivation: Bool,
    didBackground: Bool
) -> Bool {
    !hasRecordedActivation || didBackground
}
