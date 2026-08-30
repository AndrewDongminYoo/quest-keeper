import Foundation
import SwiftData

/// The single source of the on-disk store location. The app and the widget extension both open
/// *this* container so a write in one process is visible to the other.
///
/// The explicit `groupContainer` is what makes the store address deterministic across processes:
/// the widget cannot reconstruct an implicit default path, so both targets must name the App Group.
/// Callable off the main actor (the widget intent opens it inside its `@ModelActor`).
enum QuestModelContainer {
    nonisolated static func makeSchema() -> Schema {
        Schema([
            Quest.self,
            RetentionInstallation.self,
            RetentionEvent.self,
            ExperimentAssignment.self,
            DailyFocusSelection.self,
            RoutineRule.self,
            RoutineCompletion.self,
        ])
    }

    /// Last-resort in-memory container for when the on-disk store cannot be opened at all.
    ///
    /// Without it a corrupt or unmigratable App Group store makes *every* launch crash, and the only
    /// user recovery is deleting the app — which destroys the very facts that are still on disk.
    /// Facts written into this container are lost when the process exits, so a caller that falls back
    /// here MUST tell the user; see `AppStrings.storeFailureBannerBody`.
    nonisolated static func makeEphemeralFallback() -> ModelContainer {
        let schema = makeSchema()
        do {
            return try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
            )
        } catch {
            // A purely in-memory store failing is not a device condition anything can recover from.
            fatalError("Could not create an in-memory fallback ModelContainer: \(error)")
        }
    }

    /// `nonisolated` so the widget intent can open the store inside its async, off-main `perform()`
    /// (the module defaults to `@MainActor`); the app's main-actor call site is unaffected.
    nonisolated static func make(
        storeURL: URL? = nil,
        isStoredInMemoryOnly: Bool = false,
        retryKeyMigrationMarkerURL: URL? = nil
    ) throws -> ModelContainer {
        let schema = makeSchema()
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
        let markerURL = retryKeyMigrationMarkerURL
            ?? storeURL?.appendingPathExtension(RetentionRetryKeyMigrationMarkerStore.fileExtension)
            ?? FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: WidgetDungeonSnapshotStore.appGroupIdentifier
            )?.appending(path: RetentionRetryKeyMigrationMarkerStore.fileExtension)
        if !isStoredInMemoryOnly, let markerURL {
            RetentionEventRecorder.normalizeLegacyQuestRetryDeduplicationKeysIfNeeded(
                in: ModelContext(container),
                markerStore: RetentionRetryKeyMigrationMarkerStore(fileURL: markerURL)
            )
        }
        return container
    }
}
