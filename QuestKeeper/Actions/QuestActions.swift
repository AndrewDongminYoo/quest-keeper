//
//  QuestActions.swift
//  QuestKeeper
//
//  Phase 2 — fact mutations and the deletion guard. See docs/specs/003-crud-hero-view.md.
//

import Foundation

nonisolated func retryDeadlineTomorrow(from now: Date, calendar: Calendar = .current) -> Date {
    calendar.date(byAdding: .day, value: 1, to: now)
        ?? now.addingTimeInterval(24 * 60 * 60)
}

enum QuestActions {
    /// Raw cleanup is allowed for any quest; primary recovery UI should still prefer retry tomorrow for daily graves.
    nonisolated static func canDelete(_ snapshot: QuestSnapshot, at now: Date) -> Bool {
        snapshot.isDeletable(at: now)
    }

    /// Completion writes a fact; it is not deletion. Main-actor (mutates the `@Model`).
    @discardableResult
    static func complete(_ quest: Quest, at now: Date) -> Bool {
        guard quest.completedAt == nil else { return false }
        quest.completedAt = now
        return true
    }

    /// Clear the completion fact, reverting the quest toward `.pending`.
    static func uncomplete(_ quest: Quest) {
        quest.completedAt = nil
    }

    /// Move a quest back into the active dungeon by changing raw facts only.
    static func retryTomorrow(_ quest: Quest, now: Date, calendar: Calendar = .current) {
        quest.deadline = retryDeadlineTomorrow(from: now, calendar: calendar)
        quest.completedAt = nil
    }

    nonisolated static func needsChunkingGuide(deadline: Date, now: Date) -> Bool {
        deadline.timeIntervalSince(now) > GameBalance.longQuestWarningHorizon
    }
}
