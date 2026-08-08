import Foundation
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
        let expectedFrames = ["idle", "breathe-in", "breathe-out", "wind-up", "strike"]

        for gender in HeroGender.allCases {
            for hairColor in HeroHairColor.allCases {
                let appearance = HeroAppearance(gender: gender, hairColor: hairColor)
                let names = HeroFrame.allCases.map { HeroArtwork.assetName(appearance: appearance, frame: $0) }
                let expectedNames = expectedFrames.map { "sprite-hero-\(gender.rawValue)-\(hairColor.rawValue)-\($0)" }
                #expect(names == expectedNames)
            }
        }
    }

    @Test("default asset names preserve the current visual identity")
    func defaultNames() {
        #expect(HeroArtwork.assetName(appearance: .default, frame: .idle) == "sprite-hero-male-blue-idle")
        #expect(HeroArtwork.assetName(appearance: .default, frame: .strike) == "sprite-hero-male-blue-strike")
    }

    @Test("hero appearance labels resolve per locale")
    func appearanceLabelsLocalize() {
        #expect(HeroGender.male.title(locale: Locale(identifier: "ko")) == "남성형")
        #expect(HeroGender.male.title(locale: Locale(identifier: "en")) == "Masculine")
        #expect(HeroGender.female.title(locale: Locale(identifier: "en")) == "Feminine")
        #expect(HeroHairColor.black.title(locale: Locale(identifier: "ko")) == "검정")
        #expect(HeroHairColor.black.title(locale: Locale(identifier: "en")) == "Black")
    }
}
