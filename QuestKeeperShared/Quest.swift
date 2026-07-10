//
//  Quest.swift
//  QuestKeeper
//
//  Phase 1 — persistence: raw facts only. See docs/specs/002-data-model-derivation.md.
//

import Foundation
import SwiftData

/// A single to-do. Stores only immutable raw facts; every gamification value
/// (outcome, urgency, mob level, victory/grave tallies) is derived at read time.
///
/// Named `Quest` deliberately to avoid colliding with Swift Concurrency's `Task`.
@Model
final class Quest {
    var id: UUID
    var title: String
    var deadline: Date
    var completedAt: Date?
    var importance: Importance

    init(id: UUID = UUID(), title: String, deadline: Date, importance: Importance, completedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.deadline = deadline
        self.importance = importance
        self.completedAt = completedAt
    }
}

/// Stored raw fact — the *inherent* weight the user assigns to a quest, independent of time.
/// `nonisolated` so it is usable from the off-main derivation layer (this module defaults to `@MainActor`).
nonisolated enum Importance: Int, Codable, CaseIterable, Sendable {
    case low = 1
    case medium = 2
    case high = 3
}
