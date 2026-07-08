//
//  GameBalance.swift
//  QuestKeeper
//
//  Phase 1 — tunable game-balance constants, isolated from logic.
//  Everything here is derived-only; changing a number never risks a stored-state migration.
//

import Foundation

nonisolated enum GameBalance {
    /// Highest discrete mob tier a quest can present.
    static let maxMobLevel = 5

    /// How far ahead of a deadline urgency starts climbing from 0.
    static let urgencyHorizon: TimeInterval = 7 * 24 * 60 * 60   // 7 days

    /// How long the "꿱" dead-eyes frame shows on reopen before crossfading back to alive.
    static let mourningDuration: TimeInterval = 2

    /// Default local-notification lead time before a quest deadline.
    static let notificationLeadTime: TimeInterval = 60 * 60
}
