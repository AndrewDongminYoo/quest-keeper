nonisolated enum HeroGender: String, CaseIterable, Hashable, Sendable {
    case male
    case female

    var title: String { self == .male ? "남성형" : "여성형" }
}

nonisolated enum HeroHairColor: String, CaseIterable, Hashable, Sendable {
    case black
    case brown
    case blue
    case red

    var title: String {
        switch self {
        case .black: "검정"
        case .brown: "갈색"
        case .blue: "파랑"
        case .red: "빨강"
        }
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
