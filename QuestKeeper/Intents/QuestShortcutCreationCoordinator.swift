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
    let didUpdateWidgetSnapshot: Bool

    var requiresNotificationPermission: Bool {
        notificationAuthorization == .notDetermined || notificationAuthorization == .denied
    }

    var followUpFailures: Set<QuestShortcutFollowUpFailure> {
        var failures: Set<QuestShortcutFollowUpFailure> = []
        if notificationAuthorization == .unavailable { failures.insert(.notifications) }
        if !didUpdateWidgetSnapshot { failures.insert(.widgetSnapshot) }
        return failures
    }
}

@MainActor
final class QuestShortcutCreationCoordinator: Sendable {
    typealias ScheduleNotifications = @MainActor @Sendable (
        QuestSnapshot,
        Date,
        Locale
    ) async -> QuestNotificationAuthorization
    typealias ReconcileNotifications = @MainActor @Sendable (
        [QuestSnapshot],
        Date,
        Locale
    ) async -> QuestNotificationAuthorization
    typealias UpdateWidgetSnapshot = @MainActor @Sendable (WidgetDungeonPayload) async -> Bool

    private var modelContainer: ModelContainer
    private let scheduleNotifications: ScheduleNotifications
    private let reconcileNotifications: ReconcileNotifications
    private let updateWidgetSnapshot: UpdateWidgetSnapshot
    private let logger = Logger(
        subsystem: "kr.donminzzi.QuestKeeper",
        category: "CreateQuestIntent"
    )

    init(
        modelContainer: ModelContainer,
        scheduleNotifications: @escaping ScheduleNotifications,
        reconcileNotifications: @escaping ReconcileNotifications,
        updateWidgetSnapshot: @escaping UpdateWidgetSnapshot
    ) {
        self.modelContainer = modelContainer
        self.scheduleNotifications = scheduleNotifications
        self.reconcileNotifications = reconcileNotifications
        self.updateWidgetSnapshot = updateWidgetSnapshot
    }

    convenience init(
        modelContainer: ModelContainer,
        notificationService: QuestNotificationService,
        widgetSnapshotWriter: WidgetDungeonSnapshotWriter
    ) {
        self.init(
            modelContainer: modelContainer,
            scheduleNotifications: { snapshot, now, locale in
                await notificationService.syncWithoutRequestingAuthorization(
                    snapshot: snapshot,
                    now: now,
                    locale: locale
                )
            },
            reconcileNotifications: { snapshots, now, locale in
                await notificationService.reconcile(
                    snapshots: snapshots,
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
        let store = QuestStoreActor(modelContainer: modelContainer)
        let persisted = try await store.create(input: input, createdAt: now)
        let snapshot = QuestSnapshot(
            id: persisted.questID,
            deadline: persisted.deadline,
            completedAt: nil,
            importance: persisted.importance
        )

        // Reconcile the whole board rather than syncing the new quest alone: a single-quest sync
        // reserves the configured reengagement requests' capacity without planning them, and this
        // path runs without an app activation, so nothing would plan them afterwards.
        let board = try? await store.snapshots()
        let authorization: QuestNotificationAuthorization
        if let board {
            authorization = await reconcileNotifications(board, now, locale)
        } else {
            // Reconciling a board we failed to read would remove every pending request and re-add
            // only this quest's. Fall back to the single-quest sync, which touches nothing else.
            logger.error("Quest persisted but the board read for notification reconciliation failed")
            authorization = await scheduleNotifications(snapshot, now, locale)
        }
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
            didUpdateWidgetSnapshot: didUpdateWidget
        )
    }
}
