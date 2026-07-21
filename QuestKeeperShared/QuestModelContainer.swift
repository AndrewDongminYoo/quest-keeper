import Foundation
import SwiftData

/// The single source of the on-disk store location. The app and the widget extension both open
/// *this* container so a write in one process is visible to the other.
///
/// The explicit `groupContainer` is what makes the store address deterministic across processes:
/// the widget cannot reconstruct an implicit default path, so both targets must name the App Group.
/// Callable off the main actor (the widget intent opens it inside its `@ModelActor`).
enum QuestModelContainer {
    /// `nonisolated` so the widget intent can open the store inside its async, off-main `perform()`
    /// (the module defaults to `@MainActor`); the app's main-actor call site is unaffected.
    nonisolated static func make(storeURL: URL? = nil) throws -> ModelContainer {
        let schema = Schema([
            Quest.self,
            RetentionInstallation.self,
            RetentionEvent.self,
            ExperimentAssignment.self,
        ])
        let configuration: ModelConfiguration
        if let storeURL {
            configuration = ModelConfiguration(schema: schema, url: storeURL)
        } else {
            configuration = ModelConfiguration(
                schema: schema,
                groupContainer: .identifier(WidgetDungeonSnapshotStore.appGroupIdentifier)
            )
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
