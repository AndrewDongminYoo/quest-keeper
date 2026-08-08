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

        let ko = Locale(identifier: "ko")
        let en = Locale(identifier: "en")

        for gender in HeroGender.allCases {
            let koTitle = gender.title(locale: ko)
            let enTitle = gender.title(locale: en)
            #expect(!koTitle.isEmpty)
            #expect(!enTitle.isEmpty)
            #expect(koTitle != enTitle)
        }

        for hairColor in HeroHairColor.allCases {
            let koTitle = hairColor.title(locale: ko)
            let enTitle = hairColor.title(locale: en)
            #expect(!koTitle.isEmpty)
            #expect(!enTitle.isEmpty)
            #expect(koTitle != enTitle)
        }

        #expect(Set(HeroGender.allCases.map { $0.title(locale: ko) }).count == HeroGender.allCases.count)
        #expect(Set(HeroGender.allCases.map { $0.title(locale: en) }).count == HeroGender.allCases.count)
        #expect(Set(HeroHairColor.allCases.map { $0.title(locale: ko) }).count == HeroHairColor.allCases.count)
        #expect(Set(HeroHairColor.allCases.map { $0.title(locale: en) }).count == HeroHairColor.allCases.count)
    }
}
