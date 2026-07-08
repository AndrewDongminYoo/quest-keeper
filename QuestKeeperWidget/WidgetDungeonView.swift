import SwiftUI
import WidgetKit

struct WidgetDungeonView: View {
    let entry: QuestKeeperWidgetEntry

    var body: some View {
        Text("QUEST KEEPER")
            .font(.caption.bold())
            .containerBackground(.black, for: .widget)
    }
}
