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
            scheduleNotifications: { snapshot, now, locale in
                await notificationService.syncWithoutRequestingAuthorization(
                    snapshot: snapshot,
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

        let authorization = await scheduleNotifications(snapshot, now, locale)
        let didUpdateWidget: Bool
        do {
            let payload = try await store.snapshotPayload(generatedAt: now)
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
