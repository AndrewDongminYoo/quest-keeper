import Foundation
import Testing
@testable import QuestKeeper

@Suite("Monster artwork selection")
struct MonsterArtworkSelectionTests {
    @Test("mob levels map to three monster families")
    func familyMapping() {
        #expect(MonsterArtworkSelection.family(forMobLevel: 0) == .low)
        #expect(MonsterArtworkSelection.family(forMobLevel: 1) == .low)
        #expect(MonsterArtworkSelection.family(forMobLevel: 2) == .medium)
        #expect(MonsterArtworkSelection.family(forMobLevel: 3) == .medium)
        #expect(MonsterArtworkSelection.family(forMobLevel: 4) == .high)
        #expect(MonsterArtworkSelection.family(forMobLevel: 5) == .high)
    }

    @Test("fixed UUIDs reach all family variants")
    func stableVariants() {
        let ids = [
            UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        ]

        #expect(ids.map(MonsterArtworkSelection.variantIndex(forQuestID:)) == [0, 1, 2])
    }

    @Test("the same UUID keeps its variant across families")
    func familyVariants() {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

        #expect(MonsterArtworkSelection.monster(forMobLevel: 0, questID: id) == .bat)
        #expect(MonsterArtworkSelection.monster(forMobLevel: 2, questID: id) == .orc)
        #expect(MonsterArtworkSelection.monster(forMobLevel: 4, questID: id) == .golem)
    }
}
