//
//  QuestWriteFeedback.swift
//  QuestKeeper
//
//  What the user is told after a write attempt. See docs/specs/025-fact-mutation-failure-surface.md.
//

import Foundation

/// What a write attempt did, from the user's point of view.
///
/// Three cases rather than a `Bool` because a write that never happened is not a write that
/// succeeded, and the difference decides whether a standing warning may be cleared.
nonisolated enum QuestWriteOutcome: Equatable, Sendable {
    case committed
    case nothingToWrite
    case refused
}

nonisolated enum QuestWriteFeedback {
    /// Whether the rejected-write banner should be showing after `outcome`.
    ///
    /// `nothingToWrite` keeps the previous answer. Nothing reached the store, so treating it as a
    /// success would let an idempotent no-op erase a warning about a write that really was refused —
    /// and both the `hasChanges == false` early return and the recorders' `unchanged` result take
    /// that path routinely.
    static func showsFailureBanner(current: Bool, outcome: QuestWriteOutcome) -> Bool {
        switch outcome {
        case .committed: false
        case .nothingToWrite: current
        case .refused: true
        }
    }
}
