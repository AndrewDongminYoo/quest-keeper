import Foundation
import SwiftData

/// Off-main store access for the widget intent. Writes only the raw `completedAt` fact.
///
/// `@ModelActor` gives it a private `ModelContext` bound to the actor, so a bare context does not
/// fight Swift 6 strict concurrency in the intent's async `perform()`.
@ModelActor
actor QuestStoreActor {
    /// Marks a quest complete. Returns whether a write occurred — `false` if the quest is missing
    /// or already completed (idempotent, so a stale widget double-tap does nothing).
    func complete(id: UUID, now: Date) throws -> Bool {
        var descriptor = FetchDescriptor<Quest>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let quest = try modelContext.fetch(descriptor).first else { return false }
        guard quest.completedAt == nil else { return false }
        quest.completedAt = now
        try modelContext.save()
        return true
    }

    /// Re-derives the widget snapshot from the current store, within the actor's isolation.
    func snapshotPayload(generatedAt: Date) throws -> WidgetDungeonPayload {
        let quests = try modelContext.fetch(FetchDescriptor<Quest>())
        return WidgetDungeonPayload.make(from: quests, generatedAt: generatedAt)
    }
}
