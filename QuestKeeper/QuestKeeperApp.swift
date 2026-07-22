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
    @State private var hasDeferredOnboardingThisRun = false
    @State private var hasAttemptedOnboardingExposure = false
    @State private var onboardingMeasurementAvailable = false
    private let notificationDelegate: NotificationDelegate
    private let notificationService: QuestNotificationService
    private let widgetSnapshotWriter: WidgetDungeonSnapshotWriter
    private let retentionBaselineWriter: RetentionBaselineWriter?
    private let onboardingAssignment: ExperimentAssignmentSnapshot?
    private let onboardingSessionID = UUID()
    private let usesInMemoryStore: Bool
    private let isDailyFocusLoopEnabled: Bool

    init() {
#if DEBUG
        let usesInMemoryStore = ProcessInfo.processInfo.arguments.contains("-uiTestingInMemoryStore")
        let notificationService = usesInMemoryStore
            ? QuestNotificationService(center: UITestingQuestNotificationCenter())
            : QuestNotificationService.shared
        let snapshotWriter = usesInMemoryStore
            ? WidgetDungeonSnapshotWriter(save: { _ in })
            : WidgetDungeonSnapshotWriter()
#else
        let usesInMemoryStore = false
        let notificationService = QuestNotificationService.shared
        let snapshotWriter = WidgetDungeonSnapshotWriter()
#endif
        let routeStore = NotificationRouteStore()
        let delegate = NotificationDelegate(routeStore: routeStore)
        _notificationRouteStore = State(initialValue: routeStore)
        notificationDelegate = delegate
        self.notificationService = notificationService
        widgetSnapshotWriter = snapshotWriter
        retentionBaselineWriter = shouldPersistMeasurementArtifacts(
            usesInMemoryStore: usesInMemoryStore
        ) ? RetentionBaselineWriter() : nil
        self.usesInMemoryStore = usesInMemoryStore
#if DEBUG
        isDailyFocusLoopEnabled = dailyFocusLoopEnabled(arguments: ProcessInfo.processInfo.arguments)
#else
        isDailyFocusLoopEnabled = false
#endif
        UNUserNotificationCenter.current().delegate = delegate
        do {
            let container = try QuestModelContainer.make(isStoredInMemoryOnly: usesInMemoryStore)
            _sharedModelContainer = State(initialValue: container)

            let enrollment: ExperimentEnrollmentResult
            if !shouldResolveOnboardingExperiment(environment: ProcessInfo.processInfo.environment) {
                enrollment = .ineligible
            } else {
#if DEBUG
                let installationIDProvider: () throws -> UUID = usesInMemoryStore
                    ? { UUID() }
                    : { try RetentionInstallationIdentityStore.appGroup().loadOrCreate() }
                if let variant = onboardingVariantOverride(arguments: ProcessInfo.processInfo.arguments) {
                    enrollment = ExperimentAssignmentRecorder.enrollIfEligible(
                        at: .now,
                        in: container.mainContext,
                        installationIDProvider: installationIDProvider,
                        variantSelector: { variant }
                    )
                } else {
                    enrollment = ExperimentAssignmentRecorder.enrollIfEligible(
                        at: .now,
                        in: container.mainContext,
                        installationIDProvider: installationIDProvider
                    )
                }
#else
                enrollment = ExperimentAssignmentRecorder.enrollIfEligible(
                    at: .now,
                    in: container.mainContext
                )
#endif
            }

            onboardingAssignment = enrollment.assignment
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                notificationService: notificationService,
                notificationRouteStore: notificationRouteStore,
                widgetSnapshotWriter: widgetSnapshotWriter,
                onboardingAssignment: onboardingAssignment,
                onboardingMeasurementAvailable: onboardingMeasurementAvailable,
                hasDeferredOnboardingThisRun: $hasDeferredOnboardingThisRun,
                onboardingSessionID: onboardingSessionID,
                dailyFocusLoopEnabled: isDailyFocusLoopEnabled
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
                if didBackground, usesInMemoryStore {
                    didBackground = false
                    container = sharedModelContainer
                } else if didBackground,
                          let refreshed = try? QuestModelContainer.make(
                              isStoredInMemoryOnly: usesInMemoryStore
                          ) {
                    didBackground = false
                    sharedModelContainer = refreshed
                    container = refreshed
                } else {
                    container = sharedModelContainer
                }
                if shouldAttemptOnboardingExposure(
                    hasAssignment: onboardingAssignment != nil,
                    hasAttempted: hasAttemptedOnboardingExposure,
                    isActive: true
                ), let assignment = onboardingAssignment {
                    hasAttemptedOnboardingExposure = true
                    onboardingMeasurementAvailable = recordOnboardingExposure(
                        assignment: assignment,
                        at: .now,
                        in: container.mainContext
                    )
                }
                if shouldRecordRetentionActivation(
                    hasRecordedActivation: hasRecordedRetentionActivation,
                    didBackground: wasBackgrounded
                ) {
                    hasRecordedRetentionActivation = true
                    retentionBaselineWriter?.recordActivationAndWrite(
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
        let notificationService = notificationService
        Task { @MainActor in
            guard let quests = try? container.mainContext.fetch(
                FetchDescriptor<Quest>(sortBy: [SortDescriptor(\.deadline)])
            ) else { return }
            _ = await notificationService.reconcile(quests: quests, now: .now)
            await writer.submit(WidgetDungeonPayload.make(from: quests))
        }
    }
}

#if DEBUG
@MainActor
private final class UITestingQuestNotificationCenter: QuestNotificationCenter {
    func authorizationStatus() async -> UNAuthorizationStatus { .authorized }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { true }

    func add(_ request: UNNotificationRequest) async throws {}

    func pendingNotificationIdentifiers() async -> [String] { [] }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {}

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {}
}
#endif

nonisolated func dailyFocusLoopEnabled(arguments: [String]) -> Bool {
    arguments.contains("-dailyFocusLoopEnabled")
}

nonisolated func onboardingVariantOverride(
    arguments: [String]
) -> OnboardingExperimentVariant? {
    guard let flagIndex = arguments.firstIndex(of: "-onboardingVariant"),
          arguments.indices.contains(flagIndex + 1) else {
        return nil
    }
    return OnboardingExperimentVariant(rawValue: arguments[flagIndex + 1])
}

nonisolated func shouldResolveOnboardingExperiment(
    environment: [String: String]
) -> Bool {
    environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1"
}

nonisolated func shouldPersistMeasurementArtifacts(
    usesInMemoryStore: Bool
) -> Bool {
    !usesInMemoryStore
}

nonisolated func shouldRecordRetentionActivation(
    hasRecordedActivation: Bool,
    didBackground: Bool
) -> Bool {
    !hasRecordedActivation || didBackground
}

nonisolated func shouldAttemptOnboardingExposure(
    hasAssignment: Bool,
    hasAttempted: Bool,
    isActive: Bool
) -> Bool {
    hasAssignment && !hasAttempted && isActive
}

@MainActor
func recordOnboardingExposure(
    assignment: ExperimentAssignmentSnapshot,
    at occurredAt: Date,
    in context: ModelContext
) -> Bool {
    persistOnboardingExposure(
        record: {
            RetentionEventRecorder.recordExperimentExposed(
                experimentKey: assignment.experimentKey,
                at: occurredAt,
                in: context
            )
        },
        save: {
            if context.hasChanges { try context.save() }
        },
        rollback: context.rollback
    )
}

@MainActor
func persistOnboardingExposure(
    record: () -> RetentionRecordResult,
    save: () throws -> Void,
    rollback: () -> Void
) -> Bool {
    guard record() != .failed else {
        rollback()
        return false
    }
    do {
        try save()
        return true
    } catch {
        rollback()
        return false
    }
}
