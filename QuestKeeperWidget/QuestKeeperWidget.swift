import SwiftUI
import WidgetKit

struct QuestKeeperWidgetEntry: TimelineEntry {
    let date: Date
    let state: WidgetDungeonEntryState
}

struct QuestKeeperWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuestKeeperWidgetEntry {
        let date = Date()
        return QuestKeeperWidgetEntry(date: date, state: .empty(date: date))
    }

    func getSnapshot(in context: Context, completion: @escaping (QuestKeeperWidgetEntry) -> Void) {
        let date = Date()
        completion(QuestKeeperWidgetEntry(date: date, state: .empty(date: date)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuestKeeperWidgetEntry>) -> Void) {
        let date = Date()
        let entry = QuestKeeperWidgetEntry(date: date, state: .empty(date: date))
        completion(Timeline(entries: [entry], policy: .after(date.addingTimeInterval(15 * 60))))
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
