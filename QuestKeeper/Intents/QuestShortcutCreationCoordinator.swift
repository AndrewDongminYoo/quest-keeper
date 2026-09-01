import Foundation
import OSLog
import SwiftData

nonisolated enum QuestShortcutFollowUpFailure: Hashable, Sendable {
    case notifications
    case widgetSnapshot
}

nonisolated struct QuestShortcutCreationOutcome: Equatable, Sendable {
    let questID: UUID
    let retentionRecordResult: RetentionRecordResult
    let notificationAuthorization: QuestNotificationAuthorization
    /// Whether the board could be read for the reengagement refresh. It is a separate fetch from
    /// the widget payload's, so one can fail while the other succeeds; without this the shortcut
    /// would report full success with the configured reminder left unrefreshed.
    let didReadBoard: Bool
    let didUpdateWidgetSnapshot: Bool

    var requiresNotificationPermission: Bool {
        notificationAuthorization == .notDetermined || notificationAuthorization == .denied
    }

    var followUpFailures: Set<QuestShortcutFollowUpFailure> {
        var failures: Set<QuestShortcutFollowUpFailure> = []
        if notificationAuthorization == .unavailable || !didReadBoard {
            failures.insert(.notifications)
        }
        if !didUpdateWidgetSnapshot { failures.insert(.widgetSnapshot) }
        return failures
    }
}

@MainActor
final class QuestShortcutCreationCoordinator: Sendable {
    /// The second parameter reads the whole quest set, which the reengagement planner needs to
    /// choose its target, and returns `nil` when it could not be read. It is a provider rather
    /// than a value so the service can run it inside its own serialization — see
    /// `QuestNotificationService.syncAndRefreshReengagement`.
    typealias ScheduleNotifications = @MainActor @Sendable (
        QuestSnapshot,
        @escaping @MainActor @Sendable () async -> [QuestSnapshot]?,
        Date,
        Locale
    ) async -> ReengagementRefreshOutcome
    typealias UpdateWidgetSnapshot = @MainActor @Sendable (WidgetDungeonPayload) async -> Bool
    /// Reopens the on-disk store, or returns `nil` to keep the injected container.
    ///
    /// This path runs without an app activation, so the injected container can still be the warm one
    /// from before the last background — and a warm container never sees a write another process
    /// committed, which is why `QuestKeeperApp` swaps in a fresh one on `.active`. Reading through it
    /// can therefore miss a `CompleteQuestIntent` completion the widget process just wrote.
    ///
    /// It is a closure rather than an unconditional `QuestModelContainer.make()` because the caller
    /// owns which store this run is allowed to touch: a fallback, UI-testing, or in-memory run must
    /// stay on its own container instead of reaching the real App Group store.
    typealias ReopenStore = @Sendable () -> ModelContainer?

    private var modelContainer: ModelContainer
    private let reopenStore: ReopenStore
    private let scheduleNotifications: ScheduleNotifications
    private let updateWidgetSnapshot: UpdateWidgetSnapshot
    private let logger = Logger(
        subsystem: "kr.donminzzi.QuestKeeper",
        category: "CreateQuestIntent"
    )

    init(
        modelContainer: ModelContainer,
        reopenStore: @escaping ReopenStore = { nil },
        scheduleNotifications: @escaping ScheduleNotifications,
        updateWidgetSnapshot: @escaping UpdateWidgetSnapshot
    ) {
        self.modelContainer = modelContainer
        self.reopenStore = reopenStore
        self.scheduleNotifications = scheduleNotifications
        self.updateWidgetSnapshot = updateWidgetSnapshot
    }

    convenience init(
        modelContainer: ModelContainer,
        notificationService: QuestNotificationService,
        widgetSnapshotWriter: WidgetDungeonSnapshotWriter,
        reopenStore: @escaping ReopenStore
    ) {
        self.init(
            modelContainer: modelContainer,
            reopenStore: reopenStore,
            scheduleNotifications: { snapshot, readBoard, now, locale in
                await notificationService.syncAndRefreshReengagement(
                    snapshot: snapshot,
                    readBoard: readBoard,
                    now: now,
                    locale: locale
                )
            },
            updateWidgetSnapshot: { payload in
                await widgetSnapshotWriter.submit(payload)
            }
        )
    }

    func updateModelContainer(_ modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func create(
        input: QuestCreationInput,
        now: Date = .now,
        locale: Locale = .current
    ) async throws -> QuestShortcutCreationOutcome {
        // Every read below — the board for the reengagement refresh and the widget payload — has to
        // see what the widget process wrote, so the whole call runs on one reopened store rather
        // than on the possibly-warm injected container. See `ReopenStore`.
        let store = QuestStoreActor(modelContainer: reopenStore() ?? modelContainer)
        let persisted = try await store.create(input: input, createdAt: now)
        let snapshot = QuestSnapshot(
            id: persisted.questID,
            deadline: persisted.deadline,
            completedAt: nil,
            importance: persisted.importance
        )

        // The reengagement reminder targets a quest chosen from the whole board, and a single-quest
        // sync reserves its capacity without planning it. This path runs without an app activation,
        // so nothing would plan it afterwards.
        //
        // The read is handed over rather than performed here: two overlapping shortcut creations
        // that each read the board before entering the service's queue can land out of order, and
        // the later refresh would write a reminder planned from the older board.
        let refresh = await scheduleNotifications(
            snapshot,
            { try? await store.snapshots() },
            now,
            locale
        )
        if !refresh.didReadBoard {
            logger.error("Quest persisted but the board read for the reengagement refresh failed")
        }
        let authorization = refresh.authorization
        let didUpdateWidget: Bool
        do {
            let payload = try await store.snapshotPayload(generatedAt: .now)
            didUpdateWidget = await updateWidgetSnapshot(payload)
        } catch {
            didUpdateWidget = false
        }
        if persisted.retentionRecordResult == .failed {
            logger.error("Quest persisted but shortcut retention recording failed")
        }
        return QuestShortcutCreationOutcome(
            questID: persisted.questID,
            retentionRecordResult: persisted.retentionRecordResult,
            notificationAuthorization: authorization,
            didReadBoard: refresh.didReadBoard,
            didUpdateWidgetSnapshot: didUpdateWidget
        )
    }
}
