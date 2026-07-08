import Foundation
import WidgetKit

actor WidgetDungeonSnapshotWriter {
    typealias Save = @Sendable (WidgetDungeonPayload) async throws -> Void
    typealias ReloadAllTimelines = @Sendable () -> Void

    private let save: Save
    private let reloadAllTimelines: ReloadAllTimelines
    private var pendingPayload: WidgetDungeonPayload?
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
        pendingPayload = payload

        guard !isSaving else { return }
        isSaving = true

        while let nextPayload = pendingPayload {
            pendingPayload = nil

            do {
                try await save(nextPayload)
                if pendingPayload == nil {
                    reloadAllTimelines()
                }
            } catch {
                print("Failed to write widget snapshot: \(error)")
            }
        }

        isSaving = false
    }
}
