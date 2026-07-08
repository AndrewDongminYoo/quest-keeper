import SwiftUI
import WidgetKit

struct QuestKeeperWidgetEntry: TimelineEntry {
    let date: Date
    let state: WidgetDungeonEntryState
}

struct QuestKeeperWidgetProvider: TimelineProvider {
    private let store: WidgetDungeonSnapshotStore
    private let calendar: Calendar

    init(
        store: WidgetDungeonSnapshotStore = WidgetDungeonSnapshotStore(),
        calendar: Calendar = .current
    ) {
        self.store = store
        self.calendar = calendar
    }

    func placeholder(in context: Context) -> QuestKeeperWidgetEntry {
        let date = Date()
        let state = WidgetDungeonDerivation.derive(
            payload: placeholderPayload(date: date),
            at: date,
            calendar: calendar
        )
        return QuestKeeperWidgetEntry(date: date, state: state)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuestKeeperWidgetEntry) -> Void) {
        let date = Date()
        let payload = context.isPreview ? placeholderPayload(date: date) : store.load()
        let state = WidgetDungeonDerivation.derive(payload: payload, at: date, calendar: calendar)
        completion(QuestKeeperWidgetEntry(date: date, state: state))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuestKeeperWidgetEntry>) -> Void) {
        let date = Date()
        let payload = store.load()
        let state = WidgetDungeonDerivation.derive(payload: payload, at: date, calendar: calendar)
        let entry = QuestKeeperWidgetEntry(date: date, state: state)
        let refreshDate = WidgetDungeonDerivation.nextRefreshDate(
            payload: payload,
            after: date,
            calendar: calendar
        )
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private func placeholderPayload(date: Date) -> WidgetDungeonPayload {
        WidgetDungeonPayload(
            schemaVersion: WidgetDungeonPayload.currentSchemaVersion,
            generatedAt: date,
            quests: [
                WidgetQuestPayload(
                    id: UUID(),
                    title: "물 마시기",
                    deadline: date.addingTimeInterval(45 * 60),
                    completedAt: nil,
                    importanceRawValue: 2
                ),
                WidgetQuestPayload(
                    id: UUID(),
                    title: "푸시업 하나",
                    deadline: date.addingTimeInterval(3 * 60 * 60),
                    completedAt: date.addingTimeInterval(-60),
                    importanceRawValue: 1
                )
            ]
        )
    }
}

struct QuestKeeperWidget: Widget {
    let kind = "QuestKeeperWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuestKeeperWidgetProvider()) { entry in
            WidgetDungeonView(entry: entry)
        }
        .configurationDisplayName("Quest Keeper")
        .description("오늘의 던전을 홈 화면에서 확인합니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
