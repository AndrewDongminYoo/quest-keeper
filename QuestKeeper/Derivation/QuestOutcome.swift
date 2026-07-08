//
//  QuestOutcome.swift
//  QuestKeeper
//
//  Phase 1 — quest-level derivation. Pure functions of (facts, now). Never stored.
//

import Foundation

/// What a quest has resolved into, as a function of its facts and the current time.
/// Once `.victory` or `.grave`, it stays there — the deadline moment fixes it, and a late
/// completion does NOT convert a grave back into a victory (the hero already fell).
nonisolated enum QuestOutcome: Sendable, Equatable {
    case pending   // deadline not yet passed, not completed
    case victory   // completed on time (completedAt <= deadline) — an enemy defeated
    case grave     // deadline passed without on-time completion — permanent
}

nonisolated extension QuestSnapshot {
    var isCompleted: Bool { completedAt != nil }

    func outcome(at now: Date) -> QuestOutcome {
        if let completedAt {
            return completedAt <= deadline ? .victory : .grave   // late completion is still a grave
        }
        return deadline < now ? .grave : .pending
    }

    /// A grave is permanent and cannot be deleted; a pending or victorious quest can.
    /// Phase 1 exposes the predicate; Phase 2's CRUD UI enforces it.
    func isDeletable(at now: Date) -> Bool { outcome(at: now) != .grave }

    /// 0 … 1, rising as the deadline nears; only meaningful while `.pending` (0 otherwise).
    func urgency(at now: Date) -> Double {
        guard outcome(at: now) == .pending else { return 0 }
        let remaining = deadline.timeIntervalSince(now)
        if remaining >= GameBalance.urgencyHorizon { return 0 }
        return 1 - remaining / GameBalance.urgencyHorizon
    }

    /// Discrete mob tier = importance (stored) × urgency (derived), mapped into 0 … maxMobLevel.
    func mobLevel(at now: Date) -> Int {
        let raw = Double(importance.rawValue) * urgency(at: now)   // 0 … 3
        return Int((raw / 3.0 * Double(GameBalance.maxMobLevel)).rounded())
    }
}
