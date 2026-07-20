import Testing
@testable import QuestKeeper

struct DungeonArtworkTests {
    @Test("mob levels map to the three visual tiers")
    func monsterTierMapping() {
        #expect(DungeonArtwork.monster(level: 0) == .slime)
        #expect(DungeonArtwork.monster(level: 1) == .slime)
        #expect(DungeonArtwork.monster(level: 2) == .skeleton)
        #expect(DungeonArtwork.monster(level: 3) == .skeleton)
        #expect(DungeonArtwork.monster(level: 4) == .dragon)
        #expect(DungeonArtwork.monster(level: 5) == .dragon)
    }

    @Test("every artwork case has a unique asset name")
    func assetNamesAreUnique() {
        let names = DungeonArtwork.allCases.map(\.rawValue)
        #expect(Set(names).count == names.count)
    }
}
