import Testing
@testable import QuestKeeper

@Suite("Hero appearance")
struct HeroAppearanceTests {
    @Test("unknown stored values fall back to the current hero")
    func fallback() {
        #expect(HeroAppearance(genderRawValue: "unknown", hairColorRawValue: "unknown") == .default)
        #expect(HeroAppearance.default == HeroAppearance(gender: .male, hairColor: .blue))
    }

    @Test("every appearance resolves five unique asset names")
    func completeArtworkCatalog() {
        for gender in HeroGender.allCases {
            for hairColor in HeroHairColor.allCases {
                let appearance = HeroAppearance(gender: gender, hairColor: hairColor)
                let names = Set(HeroFrame.allCases.map { HeroArtwork.assetName(appearance: appearance, frame: $0) })
                #expect(names.count == 5)
            }
        }
    }

    @Test("default asset names preserve the current visual identity")
    func defaultNames() {
        #expect(HeroArtwork.assetName(appearance: .default, frame: .idle) == "sprite-hero-male-blue-idle")
        #expect(HeroArtwork.assetName(appearance: .default, frame: .strike) == "sprite-hero-male-blue-strike")
    }
}
