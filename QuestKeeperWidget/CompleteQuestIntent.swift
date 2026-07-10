import AppIntents
import SwiftData
import UserNotifications
import WidgetKit

/// One-tap completion from the Home Screen widget. Runs in the widget extension: it opens the shared
/// App Group store, writes only the raw `completedAt` fact, cancels the quest's pending notifications,
/// rewrites the snapshot the timeline reads, and reloads. Idempotent — a stale double-tap is a no-op.
struct CompleteQuestIntent: AppIntent {
    static let title: LocalizedStringResource = "퀘스트 완료"

    @Parameter(title: "questID") var questID: String

    init() {}

    init(questID: UUID) {
        self.questID = questID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: questID) else { return .result() }

        let container = try QuestModelContainer.make()
        let store = QuestStoreActor(modelContainer: container)

        let wrote = try await store.complete(id: id, now: .now)
        guard wrote else { return .result() } // already completed / missing — nothing else to do

        // Best-effort: never let a cancellation failure block the committed fact.
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: QuestNotificationKind.allCases.map { $0.identifier(for: id) }
        )

        // Rewrite the JSON snapshot the TimelineProvider reads, then reload — must not be skipped.
        let payload = try await store.snapshotPayload(generatedAt: .now)
        try? WidgetDungeonSnapshotStore().save(payload)

        WidgetCenter.shared.reloadTimelines(ofKind: "QuestKeeperWidget")
        return .result()
    }
}
