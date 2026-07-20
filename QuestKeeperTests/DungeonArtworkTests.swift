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

    @Test("breathing uses three unique hero frames in a smooth loop")
    func breathingSequence() {
        #expect(HeroAnimation.breathingFrames == [
            .heroIdle,
            .heroBreatheIn,
            .heroBreatheOut,
            .heroBreatheIn,
        ])
        #expect(Set(HeroAnimation.breathingFrames).count == 3)
    }

    @Test("mourning and Reduce Motion select stable artwork")
    func staticHeroArtwork() {
        #expect(HeroAnimation.artwork(isMourning: true, reduceMotion: false, frameIndex: 2) == .heroMourning)
        #expect(HeroAnimation.artwork(isMourning: false, reduceMotion: true, frameIndex: 2) == .heroIdle)
        #expect(HeroAnimation.artwork(isMourning: false, reduceMotion: false, frameIndex: 2) == .heroBreatheOut)
    }
}
