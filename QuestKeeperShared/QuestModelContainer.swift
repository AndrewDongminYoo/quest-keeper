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
    nonisolated static func make(
        storeURL: URL? = nil,
        isStoredInMemoryOnly: Bool = false
    ) throws -> ModelContainer {
        let schema = Schema([
            Quest.self,
            RetentionInstallation.self,
            RetentionEvent.self,
            ExperimentAssignment.self,
            DailyFocusSelection.self,
        ])
        let configuration: ModelConfiguration
        if isStoredInMemoryOnly {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else if let storeURL {
            configuration = ModelConfiguration(schema: schema, url: storeURL)
        } else {
            configuration = ModelConfiguration(
                schema: schema,
                groupContainer: .identifier(WidgetDungeonSnapshotStore.appGroupIdentifier)
            )
        }
        let container = try ModelContainer(for: schema, configurations: [configuration])
        try RetentionEventRecorder.normalizeLegacyQuestRetryDeduplicationKeys(
            in: ModelContext(container)
        )
        return container
    }
}
