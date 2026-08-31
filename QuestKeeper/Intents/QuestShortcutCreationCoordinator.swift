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
    /// The board is every quest, which the reengagement planner needs to choose its target.
    /// It is optional because the read can fail after the quest is already persisted, and a
    /// partial view is worse than none — see `QuestNotificationService.syncAndRefreshReengagement`.
    typealias ScheduleNotifications = @MainActor @Sendable (
        QuestSnapshot,
        [QuestSnapshot]?,
        Date,
        Locale
    ) async -> QuestNotificationAuthorization
    typealias UpdateWidgetSnapshot = @MainActor @Sendable (WidgetDungeonPayload) async -> Bool

    private var modelContainer: ModelContainer
    private let scheduleNotifications: ScheduleNotifications
    private let updateWidgetSnapshot: UpdateWidgetSnapshot
    private let logger = Logger(
        subsystem: "kr.donminzzi.QuestKeeper",
        category: "CreateQuestIntent"
    )

    init(
        modelContainer: ModelContainer,
        scheduleNotifications: @escaping ScheduleNotifications,
        updateWidgetSnapshot: @escaping UpdateWidgetSnapshot
    ) {
        self.modelContainer = modelContainer
        self.scheduleNotifications = scheduleNotifications
        self.updateWidgetSnapshot = updateWidgetSnapshot
    }

    convenience init(
        modelContainer: ModelContainer,
        notificationService: QuestNotificationService,
        widgetSnapshotWriter: WidgetDungeonSnapshotWriter
    ) {
        self.init(
            modelContainer: modelContainer,
            scheduleNotifications: { snapshot, board, now, locale in
                await notificationService.syncAndRefreshReengagement(
                    snapshot: snapshot,
                    board: board,
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

        // The reengagement reminder targets a quest chosen from the whole board, and a single-quest
        // sync reserves its capacity without planning it. This path runs without an app activation,
        // so nothing would plan it afterwards.
        let board = try? await store.snapshots()
        if board == nil {
            logger.error("Quest persisted but the board read for the reengagement refresh failed")
        }
        let authorization = await scheduleNotifications(snapshot, board, now, locale)
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
            didReadBoard: board != nil,
            didUpdateWidgetSnapshot: didUpdateWidget
        )
    }
}
