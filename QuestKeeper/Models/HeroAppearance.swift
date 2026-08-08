import Foundation

nonisolated enum HeroGender: String, CaseIterable, Hashable, Sendable {
    case male
    case female

    func title(locale: Locale = .current) -> String {
        AppStrings.resolve(AppStrings.heroGender(self), locale: locale)
    }
}

nonisolated enum HeroHairColor: String, CaseIterable, Hashable, Sendable {
    case black
    case brown
    case blue
    case red

    func title(locale: Locale = .current) -> String {
        AppStrings.resolve(AppStrings.heroHairColor(self), locale: locale)
    }
}

nonisolated struct HeroAppearance: Sendable, Equatable {
    static let `default` = HeroAppearance(gender: .male, hairColor: .blue)

    enum StorageKey {
        static let gender = "heroAppearance.gender"
        static let hairColor = "heroAppearance.hairColor"
    }

    let gender: HeroGender
    let hairColor: HeroHairColor

    init(gender: HeroGender, hairColor: HeroHairColor) {
        self.gender = gender
        self.hairColor = hairColor
    }

    init(genderRawValue: String, hairColorRawValue: String) {
        gender = HeroGender(rawValue: genderRawValue) ?? Self.default.gender
        hairColor = HeroHairColor(rawValue: hairColorRawValue) ?? Self.default.hairColor
    }
}
