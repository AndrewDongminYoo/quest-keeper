import Foundation
import SwiftData

/// The single source of the on-disk store location. The app and the widget extension both open
/// *this* container so a write in one process is visible to the other. Raw facts only — schema is `[Quest]`.
///
/// The explicit `groupContainer` is what makes the store address deterministic across processes:
/// the widget cannot reconstruct an implicit default path, so both targets must name the App Group.
/// Callable off the main actor (the widget intent opens it inside its `@ModelActor`).
enum QuestModelContainer {
    static func make() throws -> ModelContainer {
        let schema = Schema([Quest.self])
        let configuration = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(WidgetDungeonSnapshotStore.appGroupIdentifier)
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
