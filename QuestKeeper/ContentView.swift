//
//  ContentView.swift
//  QuestKeeper
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
    @Query(sort: \RoutineRule.createdAt) private var routineRules: [RoutineRule]
    @Query(sort: \RoutineCompletion.completedAt) private var routineCompletions: [RoutineCompletion]

    /// Transient: the deaths to mourn this activation. Drives the "꿱" frame, then resets.
    @State private var pendingDeaths: Set<UUID> = []
    /// Transient: quests whose monster grew while the app was closed. Replaced on the next activation.
    @State private var escalatedQuestIDs: Set<UUID> = []
    @State private var route: QuestSheetRoute?
    @State private var dailyFocusEditor: DailyFocusEditorRoute?
    @State private var routineSheet: RoutineSheetRoute?
    @State private var notificationAuthorization: QuestNotificationAuthorization?
    @State private var reengagementSettings: ReengagementReminderSettings
    @State private var reengagementAttribution: ReengagementNotificationAttribution?
    @State private var mourningTask: Task<Void, Never>?
    @Binding private var hasDeferredOnboardingThisRun: Bool
    @Binding private var recoveryOffer: RecoveryActivationOffer?

    private let notificationService: QuestNotificationService
    private let notificationRouteStore: NotificationRouteStore
    private let reengagementSettingsStore: ReengagementReminderSettingsStore
    private let widgetSnapshotWriter: WidgetDungeonSnapshotWriter
    private let onboardingAssignment: ExperimentAssignmentSnapshot?
    private let onboardingMeasurementAvailable: Bool
    private let onboardingSessionID: UUID
    private let dailyFocusLoopEnabled: Bool
    private let activationReplay: ActivationReplayResult?
    private let storeFailedToOpen: Bool
    /// True once a save was rejected and no later save has succeeded.
    ///
    /// Set inside `commitPendingChanges` rather than at its nine call sites: that is the one place
    /// every write converges on, so a path added later is covered without being remembered.
    @State private var lastCommitFailed = false
#if DEBUG
    private let rejectsSaves: Bool
#endif

    init(
        notificationService: QuestNotificationService = .shared,
        notificationRouteStore: NotificationRouteStore = NotificationRouteStore(),
        reengagementSettingsStore: ReengagementReminderSettingsStore = .shared,
        widgetSnapshotStore: WidgetDungeonSnapshotStore = WidgetDungeonSnapshotStore(),
        widgetSnapshotWriter: WidgetDungeonSnapshotWriter? = nil,
        onboardingAssignment: ExperimentAssignmentSnapshot? = nil,
        onboardingMeasurementAvailable: Bool = false,
        hasDeferredOnboardingThisRun: Binding<Bool> = .constant(false),
        recoveryOffer: Binding<RecoveryActivationOffer?> = .constant(nil),
        activationReplay: ActivationReplayResult? = nil,
        onboardingSessionID: UUID = UUID(),
        dailyFocusLoopEnabled: Bool = false,
        storeFailedToOpen: Bool = false
    ) {
        self.notificationService = notificationService
        self.notificationRouteStore = notificationRouteStore
        self.reengagementSettingsStore = reengagementSettingsStore
        _reengagementSettings = State(initialValue: reengagementSettingsStore.load())
        self.widgetSnapshotWriter = widgetSnapshotWriter
            ?? WidgetDungeonSnapshotWriter(snapshotStore: widgetSnapshotStore)
        self.onboardingAssignment = onboardingAssignment
        self.onboardingMeasurementAvailable = onboardingMeasurementAvailable
        self._hasDeferredOnboardingThisRun = hasDeferredOnboardingThisRun
        self._recoveryOffer = recoveryOffer
        self.activationReplay = activationReplay
        self.onboardingSessionID = onboardingSessionID
        self.dailyFocusLoopEnabled = dailyFocusLoopEnabled
        self.storeFailedToOpen = storeFailedToOpen
#if DEBUG
        rejectsSaves = LaunchArguments.saveRejectionFixtureEnabled(
            arguments: ProcessInfo.processInfo.arguments
        )
#endif
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
                // `retentionEvents` is append-only and unbounded, and this body re-runs every tick.
                // Skip the copy + sort entirely unless the guided flow can actually change the UI.
                // ponytail: the guided cohort still re-derives post-onboarding; latch on `.finished`
                // (terminal, since events only ever append) if that shows up in a trace.
                let onboardingPresentation = OnboardingFlowState.isGuidedFlowActive(
                    assignment: onboardingAssignment,
                    measurementAvailable: onboardingMeasurementAvailable
                )
                    ? OnboardingFlowState.make(
                        assignment: onboardingAssignment,
                        events: retentionEvents.map(\.snapshot),
                        pendingQuestIDs: Set(pending.map(\.id)),
                        hasExistingQuests: !quests.isEmpty,
                        deferredThisRun: hasDeferredOnboardingThisRun,
                        measurementAvailable: onboardingMeasurementAvailable
                    )
                    : .standard
                let dailyFocusPresentation = DailyFocusState.make(
                    enabled: dailyFocusLoopEnabled,
                    quests: snapshots,
                    selections: dailyFocusSelections.map(\.snapshot),
                    now: now,
                    calendar: localCalendar
                )
                let recoveryPresentation = RecoveryState.presentation(
                    offer: recoveryOffer,
                    quests: snapshots,
                    dailyFocusPresentation: dailyFocusPresentation,
                    now: now,
                    calendar: localCalendar
                )
                let routineRulesByID = Dictionary(uniqueKeysWithValues: routineRules.map { ($0.id, $0) })
                let visibleRoutines = RoutineState.visibleRoutineIDs(
                    rules: routineRules.map(\.snapshot),
                    completions: routineCompletions.map(\.snapshot),
                    now: now,
                    calendar: localCalendar
                ).compactMap { routineRulesByID[$0] }

                HomeDungeonBoardView(
                    state: state,
                    isMourning: !pendingDeaths.isEmpty,
                    allQuests: quests,
                    pending: pending,
                    dailyGraves: dailyGraves,
                    newlyMissedQuestIDs: pendingDeaths,
                    escalatedQuestIDs: escalatedQuestIDs,
                    now: now,
                    storeFailedToOpen: storeFailedToOpen,
                    lastCommitFailed: lastCommitFailed,
                    notificationPermissionAction: QuestNotificationPermissionAction.make(
                        authorization: notificationAuthorization
                    ),
                    notificationAuthorization: notificationAuthorization,
                    reengagementSettings: reengagementSettings,
                    hasCreatedQuest: hasCreatedQuest,
                    onboardingPresentation: onboardingPresentation,
                    dailyFocusPresentation: dailyFocusPresentation,
                    recoveryPresentation: recoveryPresentation,
                    visibleRoutines: visibleRoutines,
                    hasRoutineRules: !routineRules.isEmpty,
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
                            localDayKey: DailyFocusDay.key(for: now, calendar: localCalendar),
                            dismissesRecoveryOnSave: false
                        )
                    },
                    onConfirmRecoveryQuest: confirmRecoveryQuest,
                    onChooseRecoveryFocus: beginRecoveryFocusSelection,
                    onCreateRecoveryQuest: {
                        route = .recoveryCreate(.guided(at: .now))
                    },
                    onDismissRecovery: { recoveryOffer = nil },
                    onSaveReengagementSettings: saveReengagementSettings,
                    onOpenNotificationSettings: openNotificationSettings,
                    onComplete: complete,
                    onDelete: delete,
                    onOpenDetail: { route = .detail($0) },
                    onCreateRoutine: { routineSheet = .create },
                    onManageRoutines: { routineSheet = .manage },
                    onCompleteRoutine: completeRoutine
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
                        onSaved: handleQuestSaved
                    )
                case .recoveryCreate(let draft):
                    QuestEditor(
                        quest: nil,
                        draft: draft,
                        notificationService: notificationService,
                        onAuthorizationChange: { notificationAuthorization = $0 },
                        onSaved: { quest in
                            // The offer stands if the quest was not stored; clearing it would drop
                            // the recovery path for a write that never landed.
                            guard handleQuestSaved(quest) else { return false }
                            recoveryOffer = nil
                            return true
                        }
                    )
                case .detail(let quest):
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        QuestDetailView(
                            quest: quest,
                            now: context.date,
                            notificationService: notificationService,
                            onAuthorizationChange: { notificationAuthorization = $0 },
                            onSaved: { quest in
                                guard handleQuestSaved(quest) else {
                                    // The editor here is nested inside the detail sheet, so its own
                                    // dismissal only uncovers that sheet and the board's banner
                                    // stays hidden. Close the detail route too, or the refused edit
                                    // reports nothing until the user happens to back out.
                                    self.route = nil
                                    return false
                                }
                                return true
                            },
                            onRetryTomorrow: {
                                retryTomorrow(quest)
                                self.route = nil
                            },
                            onRecordLateCompletion: {
                                // The same path an on-time completion takes, so the retention event,
                                // the notification cleanup and the widget snapshot need no separate
                                // answer here — see docs/specs/024-late-completion.md.
                                complete(quest)
                                self.route = nil
                            }
                        )
                    }
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
                    guard DailyFocusDay.key(for: savedAt, calendar: localCalendar)
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
            .sheet(item: $routineSheet) { sheet in
                switch sheet {
                case .create:
                    RoutineEditor(routine: nil, onSave: saveRoutine)
                case .edit(let routine):
                    RoutineEditor(routine: routine, onSave: saveRoutine)
                case .manage:
                    RoutineManagementSheet(
                        routines: routineRules,
                        onCreate: { routineSheet = .create },
                        onEdit: { routineSheet = .edit($0) },
                        onDelete: deleteRoutine
                    )
                }
            }
            .onChange(of: recoveryOffer) { _, offer in
                if offer == nil, dailyFocusEditor?.dismissesRecoveryOnSave == true {
                    dailyFocusEditor = nil
                }
            }
            .task {
                notificationAuthorization = await notificationService.authorizationStatus()
            }
            .onChange(of: ObjectIdentifier(modelContext.container), initial: true) { _, _ in
                notificationRouteStore.resume(for: modelContext.container)
            }
            .onChange(of: notificationRouteStore.readyGeneration, initial: true) { _, _ in
                consumeNotificationRoute()
            }
            .onChange(of: notificationRouteStore.pendingQuestID, initial: true) { _, _ in
                consumeNotificationRoute()
            }
            .onChange(of: quests.map(\.id), initial: true) { _, _ in
                consumeNotificationRoute()
            }
        }
        .onChange(of: activationReplay?.id, initial: true) { _, _ in
            applyActivationReplay()
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .background:
                reengagementAttribution = nil
                if case .detail = route {
                    route = nil
                }
                switch routineSheet {
                case .edit?, .manage?:
                    routineSheet = nil
                case .create?, nil:
                    break
                }
            case .active:
                refreshNotificationAuthorization()
            default:
                break
            }
        }
    }

    // MARK: - Lifecycle

    /// 스펙 012의 첫 가치 경계. 현재 퀘스트 수가 아니라 기록된 `quest_created` 사실을 읽으므로,
    /// 사용자가 퀘스트를 모두 지워도 한 번 열린 경계는 다시 닫히지 않는다.
    ///
    /// `retentionEvents`는 append-only에 무한히 자라고 이 프로퍼티는 매 틱 다시 계산되지만,
    /// `contains`는 첫 일치에서 멈추고 `occurredAt` 오름차순 정렬이라 생성 사실은 앞쪽에 있다.
    private var hasCreatedQuest: Bool {
        retentionEvents.contains { $0.snapshot.isFirstValueQuestCreation }
    }

    private func applyActivationReplay() {
        escalatedQuestIDs = Set(activationReplay?.escalations ?? [])
        let deaths = activationReplay?.deaths ?? []
        guard !deaths.isEmpty else { return }
        mourningTask?.cancel()
        withAnimation { pendingDeaths = Set(deaths) }
        // Play once, then settle — otherwise the mourning frame latches until the next activation.
        mourningTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(GameBalance.mourningDuration))
            guard !Task.isCancelled else { return }
            withAnimation { pendingDeaths = [] }
        }
    }

    private func refreshNotificationAuthorization() {
        Task { @MainActor in
            notificationAuthorization = await notificationService.authorizationStatus()
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
        let result = DailyFocusSelectionRecorder.record(
            selectedQuestIDs: questIDs,
            kind: kind,
            at: recordedAt,
            calendar: DailyFocusDay.gregorianCalendar(timeZone: .current),
            in: modelContext
        )
        // `rejected` is a selection that does not apply, not a storage problem. The sheet stays open
        // on it, which is the accurate surface; raising the banner would misname the cause.
        switch result {
        case .inserted:
            note(.committed)
            return true
        case .unchanged:
            note(.nothingToWrite)
            return true
        case .rejected:
            note(.nothingToWrite)
            return false
        case .failed:
            note(.refused)
            return false
        }
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
            calendar: localCalendar
        )
        guard RecoveryState.canConfirmSingleQuest(
            questID,
            offer: recoveryOffer,
            quests: quests.map(\.snapshot),
            dailyFocusPresentation: dailyFocusPresentation,
            now: now,
            calendar: localCalendar
        ) else {
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
            localDayKey: DailyFocusDay.key(for: now, calendar: localCalendar),
            dismissesRecoveryOnSave: true
        )
    }

    private var localCalendar: Calendar {
        DailyFocusDay.gregorianCalendar(timeZone: .current)
    }

    private func completeRoutine(_ routine: RoutineRule) {
        switch RoutineCompletionRecorder.record(
            routineID: routine.id,
            at: .now,
            calendar: localCalendar,
            in: modelContext
        ) {
        case .inserted: note(.committed)
        // `rejected` is a stale tap, not a refused write — the board had not caught up with local
        // midnight. Reporting it as a store failure would send the user to retry something that
        // cannot succeed; the next board tick removes the row instead.
        case .unchanged, .rejected: note(.nothingToWrite)
        case .failed: note(.refused)
        }
    }

    private func saveRoutine(_ routine: RoutineRule?, title: String) -> Bool {
        let normalizedTitle = QuestTitlePolicy.normalized(title)
        guard !normalizedTitle.isEmpty else { return false }
        if let routine {
            routine.title = normalizedTitle
        } else {
            modelContext.insert(RoutineRule(title: normalizedTitle, createdAt: .now))
        }
        return commitPendingChanges()
    }

    private func deleteRoutine(_ routine: RoutineRule) {
        modelContext.delete(routine)
        _ = commitPendingChanges()
    }

    private func complete(_ quest: Quest, at completedAt: Date = .now) {
        let questID = quest.id
        let attribution = reengagementAttribution?.questID == questID ? reengagementAttribution : nil
        QuestActions.complete(quest, at: completedAt)
        _ = RetentionEventRecorder.recordQuestCompleted(
            questID: questID,
            completedAt: completedAt,
            source: .app,
            in: modelContext
        )
        if let attribution {
            _ = RetentionEventRecorder.recordReengagementNotificationCompleted(
                questID: attribution.questID,
                actionID: attribution.actionID,
                at: completedAt,
                in: modelContext
            )
        }
        // Commit before publishing: the widget snapshot must never claim a fact the store has not
        // taken. Autosave would get here on its own, but not before the snapshot is already on disk.
        guard commitPendingChanges() else { return }
        if attribution != nil {
            reengagementAttribution = nil
        }
        writeWidgetSnapshot(including: quest)
        if reengagementSettings.isEnabled {
            reconcileNotifications(at: completedAt)
        } else {
            Task { @MainActor in
                await notificationService.cancel(questID: questID)
            }
        }
    }

    /// Commits the mutation and reports whether the store took it.
    ///
    /// The side effects downstream of a fact change are not corrections a later pass will notice —
    /// cancelling a reminder for a completion the store rejected leaves the quest pending on disk
    /// with nothing left to remind about it. So a failed save rolls the change back and the caller
    /// publishes nothing; the board re-renders from the rolled-back model, which is the honest
    /// outcome rather than a screen that disagrees with disk.
    private func commitPendingChanges() -> Bool {
        guard modelContext.hasChanges else {
            note(.nothingToWrite)
            return true
        }
        do {
#if DEBUG
            if rejectsSaves {
                throw DebugSaveFailure.forcedByLaunchArgument
            }
#endif
            try modelContext.save()
            note(.committed)
            return true
        } catch {
            modelContext.rollback()
            note(.refused)
            return false
        }
    }

    /// The one place a write's outcome becomes visible to the user.
    ///
    /// Called from `commitPendingChanges` and from the two paths that do not go through it: the
    /// routine and daily-focus recorders own their own `save()`, so a failure there would otherwise
    /// be silent and a success there could never clear a standing banner.
    private func note(_ outcome: QuestWriteOutcome) {
        lastCommitFailed = QuestWriteFeedback.showsFailureBanner(
            current: lastCommitFailed,
            outcome: outcome
        )
    }

    private func retryTomorrow(_ quest: Quest) {
        let now = Date.now
        QuestActions.retryTomorrow(quest, now: now)
        _ = RetentionEventRecorder.recordQuestRetried(
            questID: quest.id,
            attemptID: UUID(),
            at: now,
            in: modelContext
        )
        guard commitPendingChanges() else { return }
        writeWidgetSnapshot(including: quest)
        if reengagementSettings.isEnabled {
            reconcileNotifications(at: now)
        } else {
            Task { @MainActor in
                let authorization = await notificationService.syncWithoutRequestingAuthorization(
                    snapshot: quest.snapshot,
                    now: now
                )
                notificationAuthorization = authorization
            }
        }
    }

    private func delete(_ quest: Quest) {
        guard QuestActions.canDelete(quest.snapshot, at: .now) else { return }
        let questID = quest.id
        // Payload first, unlike the other two: `make(from:excluding:)` reads `id` off every element
        // of `quests`, and a committed delete invalidates this instance. Build the value while the
        // object is still alive, then commit, then publish.
        let payload = WidgetDungeonPayload.make(from: quests, excluding: questID)
        modelContext.delete(quest)
        guard commitPendingChanges() else { return }
        if reengagementAttribution?.questID == questID {
            reengagementAttribution = nil
        }
        persistWidgetSnapshot(payload)
        if reengagementSettings.isEnabled {
            reconcileNotifications(at: .now)
        } else {
            Task { @MainActor in
                await notificationService.cancel(questID: questID)
            }
        }
    }

    private func writeWidgetSnapshot(including quest: Quest) {
        let payload = WidgetDungeonPayload.make(from: quests, including: quest)
        persistWidgetSnapshot(payload)
    }

    @discardableResult
    private func handleQuestSaved(_ quest: Quest) -> Bool {
        // The editor mutates or inserts into the shared context and never saves, so creation and
        // editing — the app's most common writes — reached neither the commit nor its failure
        // feedback. Commit here, on the same terms as `complete` and `delete`: publish nothing for
        // a write the store did not take.
        guard commitPendingChanges() else { return false }
        writeWidgetSnapshot(including: quest)
        if reengagementSettings.isEnabled {
            reconcileNotifications(at: .now)
        }
        return true
    }

    private func saveReengagementSettings(_ settings: ReengagementReminderSettings) {
        // 시트가 토글을 여는 근거와 같은 사실을 봐야 한다. 현재 퀘스트 수를 보면
        // 퀘스트를 모두 지운 뒤 토글은 켤 수 있는데 저장만 조용히 버려진다.
        let creationFactExists = hasCreatedQuest
        guard !settings.isEnabled || creationFactExists else { return }
        let previousSettings = reengagementSettingsStore.load()

        let now = Date.now
        if previousSettings.isEnabled != settings.isEnabled {
            let recorded = settings.isEnabled
                ? RetentionEventRecorder.recordReengagementReminderEnabled(
                    actionID: UUID(),
                    at: now,
                    in: modelContext
                )
                : RetentionEventRecorder.recordReengagementReminderDisabled(
                    actionID: UUID(),
                    at: now,
                    in: modelContext
                )
            // 측정이 남지 않은 채 설정만 저장되면 활성/비활성 쌍이 어긋나고, 나중에 성공한
            // 비활성화가 분모 없는 분자가 된다. 여기서 저장을 막는 쪽을 택한 이유는 이 실패가
            // SwiftData 저장 실패라 앱이 이미 성한 상태가 아니고, 그때 알림 설정만 살아남는
            // 편이 더 나쁘기 때문이다.
            guard recorded == .inserted, commitPendingChanges() else { return }
        }

        reengagementSettingsStore.save(settings)
        reengagementSettings = settings

        let currentQuests = quests
        Task { @MainActor in
            let status = await notificationService.authorizationStatus()
            if settings.canRequestAuthorization(hasCreatedQuest: creationFactExists), status == .notDetermined {
                let actionID = UUID()
                _ = RetentionEventRecorder.recordReengagementPermissionRequested(
                    actionID: actionID,
                    at: now,
                    in: modelContext
                )
                _ = commitPendingChanges()
                let scheduling = await notificationService.requestAuthorizationAndReconcile(
                    quests: currentQuests,
                    now: now
                )
                // `.unavailable`은 권한 거절과 스케줄링 실패를 함께 싣고 온다. 권한은 허용됐는데
                // `center.add`만 실패한 경우까지 미기록으로 두면 수락률이 낮게 잡히고 UI도 어긋나므로,
                // 그 경우에만 시스템 상태를 다시 읽는다.
                let authorization = scheduling == .unavailable
                    ? await notificationService.authorizationStatus()
                    : scheduling
                switch authorization {
                case .allowed:
                    _ = RetentionEventRecorder.recordReengagementPermissionGranted(
                        actionID: actionID,
                        at: .now,
                        in: modelContext
                    )
                case .denied:
                    _ = RetentionEventRecorder.recordReengagementPermissionDenied(
                        actionID: actionID,
                        at: .now,
                        in: modelContext
                    )
                case .notDetermined, .unavailable:
                    break
                }
                _ = commitPendingChanges()
                notificationAuthorization = authorization
            } else {
                notificationAuthorization = await notificationService.reconcile(
                    quests: currentQuests,
                    now: now
                )
            }
        }
    }

    private func reconcileNotifications(at now: Date) {
        Task { @MainActor in
            guard let currentQuests = try? modelContext.fetch(
                FetchDescriptor<Quest>(sortBy: [SortDescriptor(\.deadline)])
            ) else { return }
            notificationAuthorization = await notificationService.reconcile(quests: currentQuests, now: now)
        }
    }

    private func persistWidgetSnapshot(_ payload: WidgetDungeonPayload) {
        let snapshotWriter = widgetSnapshotWriter

        Task.detached(priority: .utility) {
            await snapshotWriter.submit(payload)
        }
    }

    private func consumeNotificationRoute() {
        guard let quest = notificationRouteStore.takeRoutedQuest(in: modelContext) else { return }

        route = .detail(quest)
        guard let attribution = notificationRouteStore.takeReengagementAttribution() else { return }
        _ = RetentionEventRecorder.recordReengagementNotificationOpened(
            questID: attribution.questID,
            actionID: attribution.actionID,
            at: .now,
            in: modelContext
        )
        guard commitPendingChanges() else { return }
        reengagementAttribution = attribution
    }

    private func openNotificationSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }
}

enum QuestSheetRoute: Identifiable {
    case create(QuestEditorDraft?)
    case recoveryCreate(QuestEditorDraft)
    case detail(Quest)

    var id: String {
        switch self {
        case .create: "create"
        case .recoveryCreate: "recovery-create"
        case .detail(let quest): "detail-\(quest.id.uuidString)"
        }
    }
}

enum RoutineSheetRoute: Identifiable {
    case create
    case edit(RoutineRule)
    case manage

    var id: String {
        switch self {
        case .create: "routine-create"
        case .edit(let routine): "routine-edit-\(routine.id.uuidString)"
        case .manage: "routine-manage"
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

#Preview {
    ContentView()
        .modelContainer(for: [Quest.self, RoutineRule.self, RoutineCompletion.self], inMemory: true)
}
