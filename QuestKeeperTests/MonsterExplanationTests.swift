//
//  MonsterExplanationTests.swift
//  QuestKeeperTests
//
//  Task 5 (AND-114) — the sheet's tier table is derived from the same mapping the
//  renderer uses, so tuning GameBalance cannot desync the explanation from reality.
//

import Testing
import Foundation
@testable import QuestKeeper

struct MonsterExplanationTests {
    @Test("tiers cover every level from 0 through maxMobLevel exactly once")
    func tiersCoverEveryLevel() {
        let tiers = MonsterExplanation.tiers(maxMobLevel: GameBalance.maxMobLevel)
        let covered = tiers.flatMap { Array($0.levels) }
        #expect(covered == Array(0...GameBalance.maxMobLevel))
    }

    @Test("each tier lists the kinds the selector can actually return for its levels")
    func tiersMatchTheSelector() {
        for tier in MonsterExplanation.tiers(maxMobLevel: GameBalance.maxMobLevel) {
            for level in tier.levels {
                #expect(MonsterArtworkSelection.family(forMobLevel: level) == tier.family)
            }
        }
    }
}
