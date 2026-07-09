import Foundation
import OSLog
import WidgetKit

actor WidgetDungeonSnapshotWriter {
    typealias Save = @Sendable (WidgetDungeonPayload) async throws -> Void
    typealias ReloadAllTimelines = @Sendable () -> Void

    private static let maximumSaveAttempts = 2

    private let save: Save
    private let reloadAllTimelines: ReloadAllTimelines
    private let logger = Logger(subsystem: "kr.donminzzi.QuestKeeper", category: "WidgetSnapshot")
    private var pendingPayload: WidgetDungeonPayload?
    private var latestSubmittedAt = Date.distantPast
    private var isSaving = false

    init(
        snapshotStore: WidgetDungeonSnapshotStore = WidgetDungeonSnapshotStore(),
        reloadAllTimelines: @escaping ReloadAllTimelines = {
            Task { @MainActor in
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    ) {
        self.save = { payload in
            try snapshotStore.save(payload)
        }
        self.reloadAllTimelines = reloadAllTimelines
    }

    init(
        save: @escaping Save,
        reloadAllTimelines: @escaping ReloadAllTimelines = {}
    ) {
        self.save = save
        self.reloadAllTimelines = reloadAllTimelines
    }

    func submit(_ payload: WidgetDungeonPayload) async {
        guard payload.generatedAt >= latestSubmittedAt else { return }
        latestSubmittedAt = payload.generatedAt
        pendingPayload = payload

        guard !isSaving else { return }
        isSaving = true

        while let nextPayload = pendingPayload {
            pendingPayload = nil

            let saved = await saveWithRetry(nextPayload)
            if saved {
                if pendingPayload == nil {
                    reloadAllTimelines()
                }
            }
        }

        isSaving = false
    }

    private func saveWithRetry(_ payload: WidgetDungeonPayload) async -> Bool {
        for attempt in 1...Self.maximumSaveAttempts {
            do {
                try await save(payload)
                return true
            } catch {
                logger.error("Failed to write widget snapshot attempt \(attempt): \(String(describing: error), privacy: .public)")
                if pendingPayload?.generatedAt ?? .distantPast > payload.generatedAt {
                    return false
                }
            }
        }

        return false
    }
}
