//
//  ContentView.swift
//  QuestKeeper
//
//  Phase 2 — root: hero header + dungeon/daily-grave sections. Wires scenePhase state-replay and
//  TimelineView live derivation to the Phase 1 layer. See docs/specs/003-crud-hero-view.md.
//

import SwiftUI
import SwiftData
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Quest.deadline) private var quests: [Quest]
    @Query(sort: \RetentionEvent.occurredAt) private var retentionEvents: [RetentionEvent]
    @Query(sort: \DailyFocusSelection.recordedAt) private var dailyFocusSelections: [DailyFocusSelection]

    /// A stored fact: when the app was last foregrounded (Phase 4 moves this to the App Group).
    @AppStorage("lastOpenedTIRD") private var lastOpenedRaw: Double = 0

    /// Transient: the deaths to mourn this activation. Drives the "꿱" frame, then resets.
    @State private var pendingDeaths: Set<UUID> = []
    @State private var recoveryOffer: RecoveryActivationOffer?
    @State private var route: EditorRoute?
    @State private var dailyFocusEditor: DailyFocusEditorRoute?
    @State private var notificationAuthorization: QuestNotificationAuthorization = .notDetermined
    @State private var mourningTask: Task<Void, Never>?
    @Binding private var hasDeferredOnboardingThisRun: Bool

    private let notificationService: QuestNotificationService
    private let notificationRouteStore: NotificationRouteStore
    private let widgetSnapshotWriter: WidgetDungeonSnapshotWriter
    private let onboardingAssignment: ExperimentAssignmentSnapshot?
    private let onboardingMeasurementAvailable: Bool
    private let onboardingSessionID: UUID
    private let dailyFocusLoopEnabled: Bool
    private let recoveryLoopVariant: RecoveryLoopVariant?

    init(
        notificationService: QuestNotificationService = .shared,
        notificationRouteStore: NotificationRouteStore = NotificationRouteStore(),
        widgetSnapshotStore: WidgetDungeonSnapshotStore = WidgetDungeonSnapshotStore(),
        widgetSnapshotWriter: WidgetDungeonSnapshotWriter? = nil,
        onboardingAssignment: ExperimentAssignmentSnapshot? = nil,
        onboardingMeasurementAvailable: Bool = false,
        hasDeferredOnboardingThisRun: Binding<Bool> = .constant(false),
        onboardingSessionID: UUID = UUID(),
        dailyFocusLoopEnabled: Bool = false,
        recoveryLoopVariant: RecoveryLoopVariant? = nil
    ) {
        self.notificationService = notificationService
        self.notificationRouteStore = notificationRouteStore
        self.widgetSnapshotWriter = widgetSnapshotWriter
            ?? WidgetDungeonSnapshotWriter(snapshotStore: widgetSnapshotStore)
        self.onboardingAssignment = onboardingAssignment
        self.onboardingMeasurementAvailable = onboardingMeasurementAvailable
        self._hasDeferredOnboardingThisRun = hasDeferredOnboardingThisRun
        self.onboardingSessionID = onboardingSessionID
        self.dailyFocusLoopEnabled = dailyFocusLoopEnabled
        self.recoveryLoopVariant = recoveryLoopVariant
    }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let now = context.date
                let snapshots = quests.map(\.snapshot)
                let state = HeroDerivation.state(quests: snapshots, now: now, lastOpened: now)
                // Derived membership — recomputed every tick, never queried (outcome depends on `now`).
                let pending = quests.filter { $0.snapshot.outcome(at: now) == .pending }
                let dailyGraves = quests.filter { $0.snapshot.isVisibleDailyGrave(at: now) }
                let onboardingPresentation = OnboardingFlowState.make(
                    assignment: onboardingAssignment,
                    events: retentionEvents.map(\.snapshot),
                    pendingQuestIDs: Set(pending.map(\.id)),
                    hasExistingQuests: !quests.isEmpty,
                    deferredThisRun: hasDeferredOnboardingThisRun,
                    measurementAvailable: onboardingMeasurementAvailable
                )
                let dailyFocusPresentation = DailyFocusState.make(
                    enabled: dailyFocusLoopEnabled,
                    quests: snapshots,
                    selections: dailyFocusSelections.map(\.snapshot),
                    now: now,
                    calendar: .current
                )
                let recoveryPresentation = RecoveryState.presentation(
                    offer: recoveryOffer,
                    quests: snapshots,
                    dailyFocusPresentation: dailyFocusPresentation,
                    now: now,
                    calendar: .current
                )

                HomeDungeonBoardView(
                    state: state,
                    isMourning: !pendingDeaths.isEmpty,
                    allQuests: quests,
                    pending: pending,
                    dailyGraves: dailyGraves,
                    newlyMissedQuestIDs: pendingDeaths,
                    now: now,
                    showsNotificationPermissionBanner: notificationAuthorization == .denied,
                    onboardingPresentation: onboardingPresentation,
                    dailyFocusPresentation: dailyFocusPresentation,
                    recoveryPresentation: recoveryPresentation,
                    onCreate: { beginQuestCreation(draft: nil) },
                    onStartGuidedQuest: {
                        beginQuestCreation(draft: .guided(at: .now))
                    },
                    onDeferOnboarding: deferOnboarding,
                    onConfirmDailyFocus: { questIDs in
                        confirmRecommendedDailyFocus(questIDs)
                    },
                    onEditDailyFocus: { questIDs, kind in
                        dailyFocusEditor = DailyFocusEditorRoute(
                            initialSelectedQuestIDs: questIDs,
                            kind: kind,
                            localDayKey: DailyFocusDay.key(for: now, calendar: .current),
                            dismissesRecoveryOnSave: false
                        )
                    },
                    onConfirmRecoveryQuest: confirmRecoveryQuest,
                    onChooseRecoveryFocus: beginRecoveryFocusSelection,
                    onCreateRecoveryQuest: {
                        route = .recoveryCreate(.guided(at: .now))
                    },
                    onDismissRecovery: { recoveryOffer = nil },
                    onOpenNotificationSettings: openNotificationSettings,
                    onComplete: complete,
                    onRetryTomorrow: retryTomorrow,
                    onDelete: delete,
                    onEdit: { route = .edit($0) }
                )
            }
            .sheet(item: $route) { route in
                switch route {
                case .create(let draft):
                    QuestEditor(
                        quest: nil,
                        draft: draft,
                        notificationService: notificationService,
                        onAuthorizationChange: { notificationAuthorization = $0 },
                        onSaved: writeWidgetSnapshot(including:)
                    )
                case .recoveryCreate(let draft):
                    QuestEditor(
                        quest: nil,
                        draft: draft,
                        notificationService: notificationService,
                        onAuthorizationChange: { notificationAuthorization = $0 },
                        onSaved: { quest in
                            recoveryOffer = nil
                            writeWidgetSnapshot(including: quest)
                        }
                    )
                case .edit(let quest):
                    QuestEditor(
                        quest: quest,
                        notificationService: notificationService,
                        onAuthorizationChange: { notificationAuthorization = $0 },
                        onSaved: writeWidgetSnapshot(including:)
                    )
                case .dailyGrave(let quest):
                    QuestResolutionView(quest: quest, now: .now) {
                        retryTomorrow(quest)
                        self.route = nil
                    }
                case .resolved(let quest):
                    QuestResolutionView(quest: quest, now: .now)
                }
            }
            .sheet(item: $dailyFocusEditor) { editor in
                let rankedIDs = DailyFocusState.rankedPendingQuestIDs(
                    quests: quests.map(\.snapshot),
                    now: .now
                )
                let questsByID = Dictionary(uniqueKeysWithValues: quests.map { ($0.id, $0) })
                let candidateIDs = rankedIDs + editor.initialSelectedQuestIDs.filter {
                    !rankedIDs.contains($0)
                }
                DailyFocusSelectionSheet(
                    quests: candidateIDs.compactMap { questsByID[$0] },
                    initialSelectedQuestIDs: editor.initialSelectedQuestIDs,
                    kind: editor.kind
                ) { questIDs in
                    let savedAt = Date.now
                    guard DailyFocusDay.key(for: savedAt, calendar: .current)
                            == editor.localDayKey else { return false }
                    let didSave = recordDailyFocus(
                        questIDs,
                        kind: editor.kind,
                        at: savedAt
                    )
                    if didSave, editor.dismissesRecoveryOnSave {
                        recoveryOffer = nil
                    }
                    return didSave
                }
            }
            .task {
                notificationAuthorization = await notificationService.authorizationStatus()
            }
            .onChange(of: notificationRouteStore.pendingQuestID, initial: true) { _, questID in
                consumeNotificationRoute(questID)
            }
            .onChange(of: quests.map(\.id), initial: true) { _, _ in
                consumeNotificationRoute(notificationRouteStore.pendingQuestID)
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { onBecameActive(now: .now) }
        }
    }

    // MARK: - Lifecycle

    private func onBecameActive(now: Date) {
        let previous = lastOpenedRaw == 0 ? nil : Date(timeIntervalSinceReferenceDate: lastOpenedRaw)
        let snapshots = quests.map(\.snapshot)
        let dailyFocusPresentation = DailyFocusState.make(
            enabled: dailyFocusLoopEnabled,
            quests: snapshots,
            selections: dailyFocusSelections.map(\.snapshot),
            now: now,
            calendar: .current
        )
        let (deaths, newLastOpened) = reconstructOnActivation(
            quests: snapshots,
            now: now,
            previousLastOpened: previous
        )
        recoveryOffer = RecoveryState.offer(
            previousLastOpened: previous,
            now: now,
            calendar: .current,
            deathsWhileAway: deaths,
            hasStoredQuests: !quests.isEmpty,
            dailyFocusPresentation: dailyFocusPresentation,
            variant: recoveryLoopVariant
        )
        lastOpenedRaw = newLastOpened.timeIntervalSinceReferenceDate

        // Only the permission banner is refreshed here — it needs no quest data, so the `@Query`'s
        // post-warm-foreground staleness can't affect it. The quest-data-dependent activation sync
        // (notification reconcile + widget snapshot) runs in `QuestKeeperApp` against the freshly
        // swapped container: acting on a stale `@Query` here would re-schedule a widget-completed
        // quest's notifications and overwrite the widget's snapshot, and opening a second container
        // for the same store in this process traps in SwiftData.
        Task { @MainActor in
            notificationAuthorization = await notificationService.authorizationStatus()
        }

        guard !deaths.isEmpty else { return }
        withAnimation { pendingDeaths = Set(deaths) }
        // Play once, then settle — otherwise the mourning frame latches until the next activation.
        mourningTask?.cancel()
        mourningTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(GameBalance.mourningDuration))
            guard !Task.isCancelled else { return }
            withAnimation { pendingDeaths = [] }
        }
    }

    // MARK: - Fact mutations

    private func beginQuestCreation(draft: QuestEditorDraft?) {
        if OnboardingFlowState.shouldRecordCreationStarted(
            assignment: onboardingAssignment,
            events: retentionEvents.map(\.snapshot),
            hasExistingQuests: !quests.isEmpty,
            measurementAvailable: onboardingMeasurementAvailable
        ), let assignment = onboardingAssignment {
            _ = RetentionEventRecorder.recordQuestCreationStarted(
                experimentKey: assignment.experimentKey,
                actionID: UUID(),
                at: .now,
                in: modelContext
            )
            try? modelContext.save()
        }
        route = .create(draft)
    }

    private func deferOnboarding() {
        if let assignment = onboardingAssignment, onboardingMeasurementAvailable {
            _ = RetentionEventRecorder.recordOnboardingDeferred(
                experimentKey: assignment.experimentKey,
                sessionID: onboardingSessionID,
                at: .now,
                in: modelContext
            )
            try? modelContext.save()
        }
        hasDeferredOnboardingThisRun = true
    }

    private func recordDailyFocus(
        _ questIDs: [UUID],
        kind: DailyFocusSelectionKind,
        at recordedAt: Date
    ) -> Bool {
        guard dailyFocusLoopEnabled else { return false }
        return DailyFocusSelectionRecorder.record(
            selectedQuestIDs: questIDs,
            kind: kind,
            at: recordedAt,
            calendar: DailyFocusDay.gregorianCalendar(timeZone: .current),
            in: modelContext
        ) != .failed
    }

    private func confirmRecommendedDailyFocus(_ displayedQuestIDs: [UUID]) {
        let tappedAt = Date.now
        let currentRecommendation = DailyFocusState.recommend(
            quests: quests.map(\.snapshot),
            now: tappedAt
        )
        guard displayedQuestIDs == currentRecommendation else { return }
        _ = recordDailyFocus(currentRecommendation, kind: .confirmation, at: tappedAt)
    }

    private func confirmRecoveryQuest(_ questID: UUID) -> Bool {
        let now = Date.now
        let dailyFocusPresentation = DailyFocusState.make(
            enabled: dailyFocusLoopEnabled,
            quests: quests.map(\.snapshot),
            selections: dailyFocusSelections.map(\.snapshot),
            now: now,
            calendar: .current
        )
        guard RecoveryState.presentation(
            offer: recoveryOffer,
            quests: quests.map(\.snapshot),
            dailyFocusPresentation: dailyFocusPresentation,
            now: now,
            calendar: .current
        ) == .singleQuest(questID) else {
            return false
        }
        guard recordDailyFocus([questID], kind: .confirmation, at: now) else {
            return false
        }
        recoveryOffer = nil
        return true
    }

    private func beginRecoveryFocusSelection() {
        let now = Date.now
        let recommendation = DailyFocusState.recommend(
            quests: quests.map(\.snapshot),
            now: now
        )
        guard !recommendation.isEmpty else { return }
        dailyFocusEditor = DailyFocusEditorRoute(
            initialSelectedQuestIDs: recommendation,
            kind: .confirmation,
            localDayKey: DailyFocusDay.key(for: now, calendar: .current),
            dismissesRecoveryOnSave: true
        )
    }

    private func complete(_ quest: Quest, at completedAt: Date = .now) {
        let questID = quest.id
        QuestActions.complete(quest, at: completedAt)
        _ = RetentionEventRecorder.recordQuestCompleted(
            questID: questID,
            completedAt: completedAt,
            source: .app,
            in: modelContext
        )
        writeWidgetSnapshot(including: quest)
        Task { @MainActor in
            await notificationService.cancel(questID: questID)
        }
    }

    private func retryTomorrow(_ quest: Quest) {
        let now = Date.now
        QuestActions.retryTomorrow(quest, now: now)
        _ = RetentionEventRecorder.recordQuestRetried(
            questID: quest.id,
            newDeadline: quest.deadline,
            at: now,
            in: modelContext
        )
        writeWidgetSnapshot(including: quest)
        Task { @MainActor in
            let authorization = await notificationService.sync(quest: quest, now: now)
            notificationAuthorization = authorization
        }
    }

    private func delete(_ quest: Quest) {
        guard QuestActions.canDelete(quest.snapshot, at: .now) else { return }
        let questID = quest.id
        modelContext.delete(quest)
        writeWidgetSnapshot(excluding: questID)
        Task { @MainActor in
            await notificationService.cancel(questID: questID)
        }
    }

    private func writeWidgetSnapshot(including quest: Quest) {
        let payload = WidgetDungeonPayload.make(from: quests, including: quest)
        persistWidgetSnapshot(payload)
    }

    private func writeWidgetSnapshot(excluding questID: UUID) {
        let payload = WidgetDungeonPayload.make(from: quests, excluding: questID)
        persistWidgetSnapshot(payload)
    }

    private func persistWidgetSnapshot(_ payload: WidgetDungeonPayload) {
        let snapshotWriter = widgetSnapshotWriter

        Task.detached(priority: .utility) {
            await snapshotWriter.submit(payload)
        }
    }

    private func consumeNotificationRoute(_ questID: UUID?) {
        guard let questID else { return }
        guard let quest = quests.first(where: { $0.id == questID }) else {
            print("Notification route is waiting for quest: \(questID)")
            return
        }

        let now = Date.now
        switch notificationDestination(for: quest.snapshot, now: now) {
        case .edit:
            route = .edit(quest)
        case .dailyGrave:
            route = .dailyGrave(quest)
        case .resolved:
            route = .resolved(quest)
        }
        notificationRouteStore.clear()
    }

    private func openNotificationSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }
}

/// Which quest, if any, the editor sheet is editing. `.create` inserts a new one.
enum EditorRoute: Identifiable {
    case create(QuestEditorDraft?)
    case recoveryCreate(QuestEditorDraft)
    case edit(Quest)
    case dailyGrave(Quest)
    case resolved(Quest)

    var id: String {
        switch self {
        case .create: "create"
        case .recoveryCreate: "recovery-create"
        case .edit(let quest): quest.id.uuidString
        case .dailyGrave(let quest): "daily-grave-\(quest.id.uuidString)"
        case .resolved(let quest): "resolved-\(quest.id.uuidString)"
        }
    }
}

struct DailyFocusEditorRoute: Identifiable {
    let id = UUID()
    let initialSelectedQuestIDs: [UUID]
    let kind: DailyFocusSelectionKind
    let localDayKey: String
    let dismissesRecoveryOnSave: Bool
}

nonisolated enum NotificationQuestDestination: Equatable {
    case edit
    case dailyGrave
    case resolved
}

nonisolated func notificationDestination(for snapshot: QuestSnapshot, now: Date) -> NotificationQuestDestination {
    switch snapshot.outcome(at: now) {
    case .pending:
        return .edit
    case .grave where snapshot.isVisibleDailyGrave(at: now):
        return .dailyGrave
    case .victory, .grave:
        return .resolved
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Quest.self, inMemory: true)
}
