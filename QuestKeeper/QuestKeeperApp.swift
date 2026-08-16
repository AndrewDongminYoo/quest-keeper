//
//  QuestKeeperApp.swift
//  QuestKeeper
//
//  Created by Dongmin yu on 7/8/26.
//

import AppIntents
import SwiftData
import SwiftUI
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
    @State private var hasPerformedActivationReplay = false
    @State private var activationReplay: ActivationReplayResult?
    @State private var recoveryOffer: RecoveryActivationOffer?
    @AppStorage("lastOpenedTIRD") private var lastOpenedRaw: Double = 0
    @State private var hasRecordedRetentionActivation = false
    @State private var retentionActivationSessionID = UUID()
    @State private var hasDeferredOnboardingThisRun = false
    @State private var hasAttemptedOnboardingExposure = false
    @State private var onboardingMeasurementAvailable = false
    private let notificationDelegate: NotificationDelegate
    private let notificationService: QuestNotificationService
    private let shortcutCreationCoordinator: QuestShortcutCreationCoordinator
    private let widgetSnapshotWriter: WidgetDungeonSnapshotWriter
    private let retentionBaselineWriter: RetentionBaselineWriter?
    private let onboardingAssignment: ExperimentAssignmentSnapshot?
    private let onboardingSessionID = UUID()
    private let usesInMemoryStore: Bool
    private let uiTestingStoreURL: URL?
    private let isDailyFocusLoopEnabled: Bool
    private let recoveryLoopVariant: RecoveryLoopVariant?
    /// True when the on-disk store could not be opened at launch and the app is running on an
    /// in-memory fallback, so nothing written survives the process. Drives the board's warning
    /// banner, and pins the run to that container — see the `.active` branch below.
    private let storeFailedToOpen: Bool

    init() {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let usesInMemoryStore = arguments.contains("-uiTestingInMemoryStore")
        let uiTestingStoreURL = LaunchArguments.parsedUITestingStoreURL(arguments: arguments)
        let forcesStoreFailure = LaunchArguments.storeFailureFixtureEnabled(arguments: arguments)
        // The failure fixture counts as a UI-testing store on its own, so the run gets the fake
        // notification centre and the no-op snapshot writer without also asking for a real store.
        let usesUITestingStore = usesInMemoryStore || uiTestingStoreURL != nil || forcesStoreFailure
        let notificationService = usesUITestingStore
            ? QuestNotificationService(center: UITestingQuestNotificationCenter())
            : QuestNotificationService.shared
        let snapshotWriter = usesUITestingStore
            ? WidgetDungeonSnapshotWriter(save: { _ in })
            : WidgetDungeonSnapshotWriter()
#else
        let usesInMemoryStore = false
        let uiTestingStoreURL: URL? = nil
        let usesUITestingStore = false
        let notificationService = QuestNotificationService.shared
        let snapshotWriter = WidgetDungeonSnapshotWriter()
#endif
        let routeStore = NotificationRouteStore()
        let delegate = NotificationDelegate(routeStore: routeStore)
        _notificationRouteStore = State(initialValue: routeStore)
        notificationDelegate = delegate
        self.notificationService = notificationService
        widgetSnapshotWriter = snapshotWriter
        retentionBaselineWriter = ActivationPolicy.shouldPersistMeasurementArtifacts(
            usesInMemoryStore: usesUITestingStore
        ) ? RetentionBaselineWriter() : nil
        self.usesInMemoryStore = usesInMemoryStore
        self.uiTestingStoreURL = uiTestingStoreURL
#if DEBUG
        let dailyFocusEnabled = LaunchArguments.dailyFocusLoopEnabled(arguments: arguments)
        isDailyFocusLoopEnabled = dailyFocusEnabled
        recoveryLoopVariant = LaunchArguments.recoveryLoopVariant(
            arguments: arguments,
            dailyFocusLoopEnabled: dailyFocusEnabled
        )
#else
        isDailyFocusLoopEnabled = false
        recoveryLoopVariant = nil
#endif
        UNUserNotificationCenter.current().delegate = delegate
        // A store that cannot be opened used to `fatalError` here, which turns a corrupt or
        // unmigratable App Group store into a permanent launch-crash loop whose only user recovery
        // is deleting the app — destroying the facts still sitting on disk. Fall back to memory so
        // the app launches, and surface `storeFailedToOpen` so the user is told nothing will persist.
        let container: ModelContainer
        do {
#if DEBUG
            if forcesStoreFailure {
                throw DebugStoreFailure.forcedByLaunchArgument
            }
#endif
            container = try QuestModelContainer.make(
                storeURL: uiTestingStoreURL,
                isStoredInMemoryOnly: usesInMemoryStore
            )
            storeFailedToOpen = false
        } catch {
            container = QuestModelContainer.makeEphemeralFallback()
            storeFailedToOpen = true
        }
        _sharedModelContainer = State(initialValue: container)
        let shortcutCreationCoordinator = QuestShortcutCreationCoordinator(
            modelContainer: container,
            notificationService: notificationService,
            widgetSnapshotWriter: snapshotWriter
        )
        self.shortcutCreationCoordinator = shortcutCreationCoordinator
        AppDependencyManager.shared.add(dependency: shortcutCreationCoordinator)
#if DEBUG
        // Kept fatal: a fixture that fails to seed would make the UI test that depends on it fail
        // for an unrelated-looking reason. `#if DEBUG`, so it cannot ship.
        do {
            try DebugFixtureSeeder.seed(
                into: container,
                arguments: arguments,
                usesUITestingStore: usesUITestingStore,
                usesInMemoryStore: usesInMemoryStore
            )
        } catch {
            fatalError("Could not seed debug fixtures: \(error)")
        }
#endif

        let enrollment: ExperimentEnrollmentResult
        if !ActivationPolicy.shouldResolveOnboardingExperiment(environment: ProcessInfo.processInfo.environment) {
            enrollment = .ineligible
        } else {
#if DEBUG
            let installationIDProvider: () throws -> UUID = usesUITestingStore
                ? { UUID() }
                : { try RetentionInstallationIdentityStore.appGroup().loadOrCreate() }
            if let variant = LaunchArguments.onboardingVariantOverride(arguments: ProcessInfo.processInfo.arguments) {
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
                recoveryOffer: $recoveryOffer,
                activationReplay: activationReplay,
                onboardingSessionID: onboardingSessionID,
                dailyFocusLoopEnabled: isDailyFocusLoopEnabled,
                storeFailedToOpen: storeFailedToOpen
            )
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .background:
                notificationRouteStore.pause()
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
                let canReplayActivation: Bool
                if didBackground, ActivationPolicy.shouldReuseContainerOnBackground(
                    usesInMemoryStore: usesInMemoryStore,
                    uiTestingStoreURL: uiTestingStoreURL
                ) {
                    didBackground = false
                    container = sharedModelContainer
                    notificationRouteStore.resume(for: container)
                    canReplayActivation = true
                    // `!storeFailedToOpen` guards the swap: on a fallback run this branch would
                    // reopen the on-disk store the moment its problem cleared and replace the
                    // container, silently discarding every quest made this session — and the banner
                    // warning about exactly that would vanish in the same frame. Stay on the
                    // fallback for the run; the next cold launch picks the real store back up.
                } else if didBackground, !storeFailedToOpen,
                          let refreshed = try? QuestModelContainer.make(
                              isStoredInMemoryOnly: usesInMemoryStore
                          ) {
                    didBackground = false
                    sharedModelContainer = refreshed
                    shortcutCreationCoordinator.updateModelContainer(refreshed)
                    container = refreshed
                    canReplayActivation = true
                } else {
                    container = sharedModelContainer
                    canReplayActivation = ActivationPolicy.shouldReplayActivation(
                        wasBackgrounded: didBackground,
                        hasFreshContainer: false
                    )
                }
                let shouldDeriveRecovery = ActivationPolicy.shouldDeriveRecoveryOffer(
                    hasRecoveryVariant: recoveryLoopVariant != nil,
                    hasPerformedActivationReplay: hasPerformedActivationReplay,
                    didBackground: wasBackgrounded
                )
                let didDeriveRecovery = canReplayActivation
                    ? replayActivation(
                        using: container,
                        at: .now,
                        shouldDeriveRecovery: shouldDeriveRecovery
                    )
                    : false
                if !canReplayActivation {
                    recoveryOffer = nil
                }
                if shouldDeriveRecovery {
                    hasPerformedActivationReplay = didDeriveRecovery
                }
                if ActivationPolicy.shouldAttemptOnboardingExposure(
                    hasAssignment: onboardingAssignment != nil,
                    hasAttempted: hasAttemptedOnboardingExposure,
                    isActive: true
                ), let assignment = onboardingAssignment {
                    hasAttemptedOnboardingExposure = true
                    onboardingMeasurementAvailable = OnboardingExposureWriter.record(
                        assignment: assignment,
                        at: .now,
                        in: container.mainContext
                    )
                }
                if ActivationPolicy.shouldRecordRetentionActivation(
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
    /// container. This runs here — not in `ContentView` — because a warm foreground's
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

    private func replayActivation(
        using container: ModelContainer,
        at now: Date,
        shouldDeriveRecovery: Bool
    ) -> Bool {
        let previousLastOpened = lastOpenedRaw == 0
            ? nil
            : Date(timeIntervalSinceReferenceDate: lastOpenedRaw)
        let calendar = DailyFocusDay.gregorianCalendar(timeZone: .current)
        guard let quests = try? container.mainContext.fetch(
            FetchDescriptor<Quest>(sortBy: [SortDescriptor(\.deadline)])
        ) else {
            if shouldDeriveRecovery {
                recoveryOffer = nil
            }
            return false
        }
        guard shouldDeriveRecovery else {
            let replay = ActivationPolicy.makeStandardActivationReplay(
                quests: quests.map(\.snapshot),
                previousLastOpened: previousLastOpened,
                now: now,
                recoveryOffer: recoveryOffer
            )
            activationReplay = replay.result
            lastOpenedRaw = replay.newLastOpened.timeIntervalSinceReferenceDate
            return false
        }
        let dailyFocusSelections = try? container.mainContext.fetch(
            FetchDescriptor<DailyFocusSelection>(
                sortBy: [SortDescriptor(\.recordedAt)]
            )
        )
        let replay = Activation.makeActivationReplay(
            quests: quests.map(\.snapshot),
            dailyFocusSelections: dailyFocusSelections?.map(\.snapshot),
            previousLastOpened: previousLastOpened,
            now: now,
            calendar: calendar,
            dailyFocusLoopEnabled: isDailyFocusLoopEnabled,
            recoveryLoopVariant: recoveryLoopVariant
        )
        recoveryOffer = replay.result.recoveryOffer
        activationReplay = replay.result
        lastOpenedRaw = replay.newLastOpened.timeIntervalSinceReferenceDate
        return true
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

/// Launch-argument parsing. A namespace rather than file-scope functions so these never collide with
/// the same-named stored properties on `QuestKeeperApp` (`recoveryLoopVariant` already did, which is
/// why the call site once needed a `QuestKeeper.` module qualifier).
nonisolated enum LaunchArguments {
    static func dailyFocusLoopEnabled(arguments: [String]) -> Bool {
        arguments.contains("-dailyFocusLoopEnabled")
    }

    static func recoveryLoopVariant(
        arguments: [String],
        dailyFocusLoopEnabled: Bool
    ) -> RecoveryLoopVariant? {
        guard dailyFocusLoopEnabled,
              let index = arguments.firstIndex(of: "-recoveryLoopVariant"),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return RecoveryLoopVariant(rawValue: arguments[index + 1])
    }

    static func onboardingVariantOverride(
        arguments: [String]
    ) -> OnboardingExperimentVariant? {
        guard let flagIndex = arguments.firstIndex(of: "-onboardingVariant"),
              arguments.indices.contains(flagIndex + 1) else {
            return nil
        }
        return OnboardingExperimentVariant(rawValue: arguments[flagIndex + 1])
    }

#if DEBUG
    static func parsedUITestingStoreURL(arguments: [String]) -> URL? {
        guard let index = arguments.firstIndex(of: "-uiTestingStoreURL"),
              arguments.indices.contains(index + 1) else { return nil }
        return URL(fileURLWithPath: arguments[index + 1])
    }

    /// Forces the store open to fail so a UI test can reach the in-memory fallback and its banner.
    /// There is no way to corrupt a real App Group store from a test, and simulating the *result*
    /// (setting the flag directly) would assert nothing about the path that actually runs.
    static func storeFailureFixtureEnabled(arguments: [String]) -> Bool {
        arguments.contains("-uiTestingStoreFailure")
    }
#endif
}

#if DEBUG
/// The error `-uiTestingStoreFailure` throws in place of a real store-open failure.
enum DebugStoreFailure: Error {
    case forcedByLaunchArgument
}
#endif

/// Pure predicates deciding what the `.active` scene-phase transition should do. Kept side-effect free
/// so each rule is testable without a container, a scene, or a simulator.
nonisolated enum ActivationPolicy {
    static func shouldReuseContainerOnBackground(
        usesInMemoryStore: Bool,
        uiTestingStoreURL: URL?
    ) -> Bool {
        usesInMemoryStore || uiTestingStoreURL != nil
    }

    static func shouldReplayActivation(
        wasBackgrounded: Bool,
        hasFreshContainer: Bool
    ) -> Bool {
        !wasBackgrounded || hasFreshContainer
    }

    static func shouldDeriveRecoveryOffer(
        hasRecoveryVariant: Bool,
        hasPerformedActivationReplay: Bool,
        didBackground: Bool
    ) -> Bool {
        hasRecoveryVariant && (!hasPerformedActivationReplay || didBackground)
    }

    static func shouldResolveOnboardingExperiment(
        environment: [String: String]
    ) -> Bool {
        environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1"
    }

    static func shouldPersistMeasurementArtifacts(
        usesInMemoryStore: Bool
    ) -> Bool {
        !usesInMemoryStore
    }

    static func shouldRecordRetentionActivation(
        hasRecordedActivation: Bool,
        didBackground: Bool
    ) -> Bool {
        !hasRecordedActivation || didBackground
    }

    static func shouldAttemptOnboardingExposure(
        hasAssignment: Bool,
        hasAttempted: Bool,
        isActive: Bool
    ) -> Bool {
        hasAssignment && !hasAttempted && isActive
    }

    /// The non-recovery activation-replay path (`shouldDeriveRecovery == false`): reconstruct deaths and
    /// escalations against `previousLastOpened` and always return a fresh result. Unconditional on purpose —
    /// mirrors `makeActivationReplay`'s unconditional publish, so both paths give `ContentView` a
    /// replace-on-every-activation result whether or not anything died this activation. `escalationsWhileAway`
    /// is independent of `deathsWhileAway`, so gating the result on `!deaths.isEmpty` (the pre-fix shape) would
    /// silently drop an escalation-only activation — the common case, since it needs no death.
    static func makeStandardActivationReplay(
        quests: [QuestSnapshot],
        previousLastOpened: Date?,
        now: Date,
        recoveryOffer: RecoveryActivationOffer?,
        id: UUID = UUID()
    ) -> (result: ActivationReplayResult, newLastOpened: Date) {
        let (deaths, escalations, newLastOpened) = Activation.reconstructOnActivation(
            quests: quests,
            now: now,
            previousLastOpened: previousLastOpened
        )
        return (
            ActivationReplayResult(
                id: id,
                deaths: deaths,
                escalations: escalations,
                recoveryOffer: recoveryOffer
            ),
            newLastOpened
        )
    }
}

@MainActor
enum OnboardingExposureWriter {
    static func record(
        assignment: ExperimentAssignmentSnapshot,
        at occurredAt: Date,
        in context: ModelContext
    ) -> Bool {
        persist(
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

    static func persist(
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
}
