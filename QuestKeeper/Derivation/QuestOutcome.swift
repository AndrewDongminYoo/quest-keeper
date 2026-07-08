//
//  QuestOutcome.swift
//  QuestKeeper
//
//  Phase 1 — quest-level derivation. Pure functions of (facts, now). Never stored.
//

import Foundation

/// What a quest has resolved into, as a function of its facts and the current time.
/// Once `.victory` or `.grave`, it stays there until raw facts change, and a late
/// completion does NOT convert a grave back into a victory (the hero already fell).
nonisolated enum QuestOutcome: Sendable, Equatable {
    case pending   // deadline not yet passed, not completed
    case victory   // completed on time (completedAt <= deadline) — an enemy defeated
    case grave     // deadline passed without on-time completion
}

nonisolated extension QuestSnapshot {
    var isCompleted: Bool { completedAt != nil }

    func outcome(at now: Date) -> QuestOutcome {
        if let completedAt {
            return completedAt <= deadline ? .victory : .grave   // late completion is still a grave
        }
        return deadline < now ? .grave : .pending
    }

    /// Raw cleanup policy is owned by actions/UI; a grave is not a permanent lock.
    func isDeletable(at now: Date) -> Bool { true }

    /// Daily grave presentation is temporary and resets by local day.
    func isVisibleDailyGrave(at now: Date, calendar: Calendar = .current) -> Bool {
        guard outcome(at: now) == .grave else { return false }
        return calendar.isDate(deadline, inSameDayAs: now)
    }

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
