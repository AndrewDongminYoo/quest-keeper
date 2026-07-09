//
//  HeroDerivation.swift
//  QuestKeeper
//
//  Phase 1 — hero derivation. A scoreboard, not a health meter: the hero is always alive.
//

import Foundation

/// The hero's derived standing. Never persisted.
///
/// There is no `hp`/`isDead`: a missed deadline is a momentary "꿱 → revive" *event*
/// (`deathsWhileAway`), not a lingering state.
nonisolated struct HeroState: Sendable, Equatable {
    let totalVictories: Int
    let dailyGraves: [UUID]

    /// Quests whose deadline fell within `(lastOpened, now]` and resolved to a grave —
    /// drives the "꿱 → revive" moment shown on reopen. This is transient replay input.
    let deathsWhileAway: [UUID]
}

nonisolated enum HeroDerivation {
    /// Deterministic in all three inputs — same inputs, same output.
    static func state(
        quests: [QuestSnapshot],
        now: Date,
        lastOpened: Date,
        calendar: Calendar = .current
    ) -> HeroState {
        var totalVictories = 0
        var dailyGraves: [UUID] = []
        for quest in quests {
            switch quest.outcome(at: now) {
            case .victory:
                totalVictories += 1
            case .grave:
                if quest.isVisibleDailyGrave(at: now, calendar: calendar) {
                    dailyGraves.append(quest.id)
                }
            case .pending: break
            }
        }

        let deathsWhileAway = quests
            .filter { $0.deadline > lastOpened && $0.deadline <= now && $0.outcome(at: now) == .grave }
            .map(\.id)

        return HeroState(totalVictories: totalVictories, dailyGraves: dailyGraves, deathsWhileAway: deathsWhileAway)
    }
}
