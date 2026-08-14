import Foundation
import SwiftData

nonisolated struct QuestStoreCreateResult: Equatable, Sendable {
    let questID: UUID
    let deadline: Date
    let importance: Importance
    let retentionRecordResult: RetentionRecordResult
}

/// Actor-owned store access for shortcut creation, widget completion, and widget snapshot reads.
///
/// `@ModelActor` keeps Quest and retention writes inside a private `ModelContext`, avoiding cross-actor SwiftData models under Swift 6 strict concurrency.
@ModelActor
actor QuestStoreActor {
    func create(
        input: QuestCreationInput,
        id: UUID = UUID(),
        createdAt: Date
    ) throws -> QuestStoreCreateResult {
        let quest = Quest(
            id: id,
            title: input.title,
            deadline: input.deadline,
            importance: input.importance,
            details: input.details
        )
        modelContext.insert(quest)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }

        let supportsRetentionMeasurement = modelContainer.schema.entity(
            for: RetentionInstallation.self
        ) != nil && modelContainer.schema.entity(for: RetentionEvent.self) != nil
        guard supportsRetentionMeasurement else {
            return QuestStoreCreateResult(
                questID: id,
                deadline: input.deadline,
                importance: input.importance,
                retentionRecordResult: .failed
            )
        }

        var retentionResult = RetentionEventRecorder.recordQuestCreated(
            questID: id,
            at: createdAt,
            source: .shortcut,
            in: modelContext
        )
        if retentionResult == .inserted {
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
                retentionResult = .failed
            }
        } else if retentionResult == .failed {
            modelContext.rollback()
        }
        return QuestStoreCreateResult(
            questID: id,
            deadline: input.deadline,
            importance: input.importance,
            retentionRecordResult: retentionResult
        )
    }

    /// Marks a quest complete. Returns whether a write occurred — `false` if the quest is missing
    /// or already completed (idempotent, so a stale widget double-tap does nothing).
    func complete(id: UUID, now: Date) throws -> Bool {
        var descriptor = FetchDescriptor<Quest>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let quest = try modelContext.fetch(descriptor).first else { return false }
        guard quest.completedAt == nil else { return false }
        quest.completedAt = now
        _ = RetentionEventRecorder.recordQuestCompleted(
            questID: id,
            completedAt: now,
            source: .widget,
            in: modelContext
        )
        try modelContext.save()
        return true
    }

    /// Re-derives the widget snapshot from the current store, within the actor's isolation.
    func snapshotPayload(generatedAt: Date) throws -> WidgetDungeonPayload {
        let quests = try modelContext.fetch(FetchDescriptor<Quest>())
        return WidgetDungeonPayload.make(from: quests, generatedAt: generatedAt)
    }
}
