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
/// (`deathsWhileAway`), not a lingering state. The only enduring record is `graves`.
nonisolated struct HeroState: Sendable, Equatable {
    let victories: Int          // enemies defeated (on-time completions)
    let graves: Int             // permanent failures — monotonic over real time

    /// Quests whose deadline fell within `(lastOpened, now]` and resolved to a grave —
    /// drives the "꿱 → revive" moment shown on reopen. Independent of the tallies above.
    let deathsWhileAway: [UUID]
}

nonisolated enum HeroDerivation {
    /// Deterministic in all three inputs — same inputs, same output.
    static func state(quests: [QuestSnapshot], now: Date, lastOpened: Date) -> HeroState {
        var victories = 0
        var graves = 0
        for quest in quests {
            switch quest.outcome(at: now) {
            case .victory: victories += 1
            case .grave: graves += 1
            case .pending: break
            }
        }

        let deathsWhileAway = quests
            .filter { $0.deadline > lastOpened && $0.deadline <= now && $0.outcome(at: now) == .grave }
            .map(\.id)

        return HeroState(victories: victories, graves: graves, deathsWhileAway: deathsWhileAway)
    }
}
