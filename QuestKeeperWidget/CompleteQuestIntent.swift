import AppIntents
import OSLog
import SwiftData
import UserNotifications
import WidgetKit

/// `nonisolated` because the widget module defaults to `@MainActor` while `perform()` runs off it.
private nonisolated let logger = Logger(
    subsystem: "kr.donminzzi.QuestKeeper.Widget",
    category: "CompleteQuestIntent"
)

/// One-tap completion from the Home Screen widget. Runs in the widget extension: it opens the shared
/// App Group store, writes only the raw `completedAt` fact, cancels the quest's notifications,
/// rewrites the snapshot the timeline reads, and reloads. Idempotent — a stale double-tap is a no-op.
struct CompleteQuestIntent: AppIntent {
    static let title: LocalizedStringResource = LocalizedStringResource(
        "appIntent.completeQuest.title",
        defaultValue: "퀘스트 완료"
    )

    // ExtractAppIntentsMetadata는 LocalizedStringResource를 이 자리에 직접 써야 인식한다.
    @Parameter(title: LocalizedStringResource(
        "appIntent.completeQuest.questParameter",
        defaultValue: "퀘스트"
    )) var questID: String

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
        let notificationIdentifiers = QuestNotificationKind.allCases.map { $0.identifier(for: id) }
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.removePendingNotificationRequests(withIdentifiers: notificationIdentifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: notificationIdentifiers)

        // Rewrite the JSON snapshot the TimelineProvider reads, then reload. This is the ONLY refresh
        // path for a widget tap, so a swallowed failure would leave the widget showing the completed
        // quest until the next app-side write. Retry, and reload only after the snapshot is on disk;
        // if every attempt fails, the `completedAt` fact is still committed and the app's next
        // foreground rewrites the snapshot — so we log rather than surface an error to the tap.
        let payload = try await store.snapshotPayload(generatedAt: .now)
        let snapshotStore = WidgetDungeonSnapshotStore()
        var saved = false
        for attempt in 1...2 {
            do {
                try snapshotStore.save(payload)
                saved = true
                break
            } catch {
                logger.error(
                    "Failed to write widget snapshot after completion, attempt \(attempt): \(String(describing: error), privacy: .public)"
                )
                // Back off like the app-side writer does; an immediate retry re-hits whatever
                // transient condition (a concurrent write, a busy volume) just failed.
                if attempt < 2 {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
            }
        }

        if saved {
            WidgetCenter.shared.reloadTimelines(ofKind: "QuestKeeperWidget")
        }
        return .result()
    }
}
