//
//  Activation.swift
//  QuestKeeper
//
//  Phase 2 — the scenePhase state-replay core, extracted as a pure function so it needs no view.
//  See docs/specs/003-crud-hero-view.md §2.
//

import Foundation

/// What died in `(previousLastOpened, now]`, and the clock to store next.
///
/// Reconstruct against the *previous* `lastOpened`, then advance — the caller persists `newLastOpened`
/// AFTER surfacing `deaths`, so a subsequent activation with that value replays nothing.
/// `nonisolated` (over `[QuestSnapshot]`) so it runs off the main actor and is directly testable.
nonisolated func reconstructOnActivation(
    quests: [QuestSnapshot],
    now: Date,
    previousLastOpened: Date?
) -> (deaths: [UUID], newLastOpened: Date) {
    let previous = previousLastOpened ?? now
    let state = HeroDerivation.state(quests: quests, now: now, lastOpened: previous)
    return (state.deathsWhileAway, now)
}
