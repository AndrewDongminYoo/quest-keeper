//
//  QuestSnapshot.swift
//  QuestKeeper
//
//  Phase 1 — the derivation seam. See docs/specs/002-data-model-derivation.md.
//

import Foundation

/// A `Sendable` value projection of a `Quest`'s raw facts.
///
/// Derivation operates on this, never on the `@Model` class: it keeps the logic pure and
/// `Sendable` under Swift 6, and lets tests build inputs by hand without a `ModelContainer`.
/// `title` is intentionally omitted — it plays no part in derivation.
///
/// `nonisolated`: the whole derivation layer runs off the main actor (this module defaults to
/// `@MainActor`), so it stays callable from the widget timeline provider and background reconstruction.
nonisolated struct QuestSnapshot: Sendable, Identifiable, Equatable {
    let id: UUID
    let deadline: Date
    let completedAt: Date?
    let importance: Importance
}

extension Quest {
    var snapshot: QuestSnapshot {
        QuestSnapshot(id: id, deadline: deadline, completedAt: completedAt, importance: importance)
    }
}
