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

    @Test("app artwork resolves the shared monster identity")
    func appArtworkUsesSharedIdentity() {
        let ids = [
            UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        ]

        for level in [0, 2, 4] {
            for id in ids {
                let identity = MonsterArtworkSelection.monster(forMobLevel: level, questID: id)
                #expect(DungeonArtwork.monster(level: level, questID: id).rawValue == identity.assetName)
            }
        }
    }

    @Test("monster names resolve per locale")
    func monsterNamesLocalize() {
        #expect(MonsterKind.slime.localizedName(locale: Locale(identifier: "ko")) == "슬라임")
        #expect(MonsterKind.slime.localizedName(locale: Locale(identifier: "en")) == "Slime")
        #expect(MonsterKind.lich.localizedName(locale: Locale(identifier: "ko")) == "리치")
        #expect(MonsterKind.lich.localizedName(locale: Locale(identifier: "en")) == "Lich")
    }
}
