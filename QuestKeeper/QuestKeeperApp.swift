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
    /// 팁 거래 리스너의 소유자. 시트가 열려 있는지와 무관하게 프로세스가 사는 동안 유지된다.
    /// 같은 인스턴스를 AboutSheet까지 주입해, Ask to Buy 승인이나 중단된 구매를 정리한 결과가
    /// 이미 열린 시트의 모델에도 전달되게 한다.
    @State private var tipJarStore = StoreKitTipJarStore()
    private let notificationDelegate: NotificationDelegate
    private let notificationService: QuestNotificationService
    private let reengagementSettingsStore: ReengagementReminderSettingsStore
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
        // Deliberately NOT folded into `usesUITestingStore`. The fixture's job is to reach the
        // fallback the way production reaches it, so the inert dependencies it ends up with have to
        // come from `storeFailedToOpen` — the condition that fires in a shipped build — rather than
        // from a testing flag that would substitute them for a different reason and hide the real one.
        let usesUITestingStore = usesInMemoryStore || uiTestingStoreURL != nil
        let deniesNotificationAuthorization = LaunchArguments.notificationDenialFixtureEnabled(
            arguments: arguments
        )
#else
        let usesInMemoryStore = false
        let uiTestingStoreURL: URL? = nil
        let usesUITestingStore = false
        let deniesNotificationAuthorization = false
#endif
        let routeStore = NotificationRouteStore()
        let delegate = NotificationDelegate(routeStore: routeStore)
        _notificationRouteStore = State(initialValue: routeStore)
        notificationDelegate = delegate
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
        // Every dependency that writes outside this process is chosen here, after the store's fate
        // is known — not before it. On a fallback run the quests in the container are ephemeral, so
        // publishing them would overwrite the widget snapshot built from the surviving on-disk data
        // and schedule reminders for facts that die at process exit. Gating each call site would
        // mean finding all of them and keeping them found; making the dependency inert covers the
        // ones nobody thought about, including whatever the editor grows next.
        let usesInertSideEffects = ActivationPolicy.shouldUseInertSideEffects(
            usesUITestingStore: usesUITestingStore,
            storeFailedToOpen: storeFailedToOpen
        )
        // 이 실행의 퀘스트는 프로세스와 함께 사라지는데 알림 설정만 실제 저장소에 남으면,
        // 복구된 다음 실행에서 살아남은 무관한 퀘스트에 알림이 예약된다.
        let reengagementSettingsStore: ReengagementReminderSettingsStore =
            usesInertSideEffects ? .ephemeral() : .shared
        self.reengagementSettingsStore = reengagementSettingsStore
        let notificationService = usesInertSideEffects
            ? QuestNotificationService(
                center: InertQuestNotificationCenter(
                    authorizationStatus: deniesNotificationAuthorization ? .denied : .authorized
                ),
                reengagementSettingsStore: reengagementSettingsStore
            )
            : QuestNotificationService.shared
        let snapshotWriter = usesInertSideEffects
            ? WidgetDungeonSnapshotWriter(save: { _ in })
            : WidgetDungeonSnapshotWriter()
        self.notificationService = notificationService
        widgetSnapshotWriter = snapshotWriter
        retentionBaselineWriter = ActivationPolicy.shouldPersistMeasurementArtifacts(
            usesInMemoryStore: usesUITestingStore,
            storeFailedToOpen: storeFailedToOpen
        ) ? RetentionBaselineWriter() : nil
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
        // An empty fallback store looks exactly like a fresh install to the eligibility check, so
        // enrolling here would assign a variant off a container that dies with the process — and
        // the exposure it triggers would be written into the same nowhere.
        if storeFailedToOpen
            || !ActivationPolicy.shouldResolveOnboardingExperiment(environment: ProcessInfo.processInfo.environment) {
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
                reengagementSettingsStore: reengagementSettingsStore,
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
            .environment(\.tipJarStore, tipJarStore)
            .task { await tipJarStore.listenForTransactions() }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .background:
                notificationRouteStore.pause()
                didBackground = true
                retentionActivationSessionID = UUID()
            case .active:
                // A fallback run stops here. Its container holds none of the user's facts, and
                // everything below treats the container as the truth — `syncActivation` would cancel
                // every pending reminder the real quests still need and publish an empty widget
                // payload, `replayActivation` would advance `lastOpened` past deaths that were never
                // shown, and the baseline export would overwrite the real report. It also keeps the
                // run on its fallback container: the refresh branch below would otherwise reopen the
                // on-disk store the moment its problem cleared and discard everything made this
                // session, in the same frame as the banner warning about that disappeared.
                //
                // The route store still needs resuming: `pause()` cleared it on the way out, and
                // `ContentView`'s container-identity observer cannot fire because that identity
                // never changes here.
                guard ActivationPolicy.shouldRunActivationSideEffects(
                    storeFailedToOpen: storeFailedToOpen
                ) else {
                    didBackground = false
                    notificationRouteStore.resume(for: sharedModelContainer)
                    break
                }
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
                } else if didBackground,
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

/// A notification centre that accepts everything and schedules nothing.
///
/// Used for UI-testing runs and — the reason it is no longer `#if DEBUG` — for a production
/// fallback run, whose quests do not outlive the process and so must not leave reminders behind.
/// It reports `.authorized` by default so the board does not also nag for a permission this run
/// cannot use; a UI test can hand it `.denied` to read the settings sheet's denial route.
@MainActor
private final class InertQuestNotificationCenter: QuestNotificationCenter {
    private let status: UNAuthorizationStatus

    init(authorizationStatus: UNAuthorizationStatus = .authorized) {
        status = authorizationStatus
    }

    func authorizationStatus() async -> UNAuthorizationStatus { status }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { true }

    func add(_ request: UNNotificationRequest) async throws {}

    func pendingNotificationIdentifiers() async -> [String] { [] }

    func pendingQuestNotifications() async -> [PendingQuestNotification] { [] }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {}

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {}
}

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

    /// Makes the inert centre report `.denied` so a UI test can read the settings sheet's denial
    /// route. The substitution stops at the `QuestNotificationCenter` seam, which CLAUDE.md names
    /// as the test seam — the service, the board, and the sheet all run their real code above it.
    static func notificationDenialFixtureEnabled(arguments: [String]) -> Bool {
        arguments.contains("-uiTestingNotificationDenied")
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
        usesInMemoryStore: Bool,
        storeFailedToOpen: Bool
    ) -> Bool {
        !usesInMemoryStore && !storeFailedToOpen
    }

    /// Whether the run gets dependencies that write nowhere. A fallback qualifies for the same
    /// reason a UI-testing store does: its quests are ephemeral, so publishing them would overwrite
    /// the widget snapshot built from the surviving on-disk data and leave reminders for facts that
    /// die with the process.
    static func shouldUseInertSideEffects(
        usesUITestingStore: Bool,
        storeFailedToOpen: Bool
    ) -> Bool {
        usesUITestingStore || storeFailedToOpen
    }

    /// A fallback run holds none of the user's facts, so every activation side effect below would
    /// act on an empty store as if it were the truth: `reconcile` cancels reminders the real quests
    /// still need, the snapshot writer blanks the widget, the baseline export overwrites the report
    /// derived from the real store, and the replay clock advances past deaths that were never shown.
    /// Render the board, run none of it.
    static func shouldRunActivationSideEffects(storeFailedToOpen: Bool) -> Bool {
        !storeFailedToOpen
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
