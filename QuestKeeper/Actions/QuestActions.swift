//
//  QuestActions.swift
//  QuestKeeper
//
//  Phase 2 — fact mutations and the deletion guard. See docs/specs/003-crud-hero-view.md.
//

import Foundation

enum QuestActions {
    /// Pure guard — a grave can never be deleted; everything else can.
    /// `nonisolated` and over a `QuestSnapshot`, so it is unit-testable without a container.
    nonisolated static func canDelete(_ snapshot: QuestSnapshot, at now: Date) -> Bool {
        snapshot.isDeletable(at: now)
    }

    /// Completion writes a fact; it is not deletion. Main-actor (mutates the `@Model`).
    static func complete(_ quest: Quest, at now: Date) {
        quest.completedAt = now
    }

    /// Clear the completion fact, reverting the quest toward `.pending`.
    static func uncomplete(_ quest: Quest) {
        quest.completedAt = nil
    }
}
