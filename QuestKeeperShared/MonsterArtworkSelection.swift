import Foundation

nonisolated enum MonsterFamily: Sendable, Equatable {
    case low
    case medium
    case high
}

nonisolated enum MonsterKind: String, CaseIterable, Sendable {
    case slime
    case bat
    case mushroom
    case skeleton
    case orc
    case mimic
    case dragon
    case golem
    case lich

    var assetName: String { "sprite-\(rawValue)" }

    var localizedName: String {
        switch self {
        case .slime: "슬라임"
        case .bat: "박쥐"
        case .mushroom: "버섯"
        case .skeleton: "스켈레톤"
        case .orc: "오크"
        case .mimic: "미믹"
        case .dragon: "드래곤"
        case .golem: "골렘"
        case .lich: "리치"
        }
    }
}

nonisolated enum MonsterArtworkSelection {
    static func family(forMobLevel level: Int) -> MonsterFamily {
        switch level {
        case ..<2: .low
        case 2..<4: .medium
        default: .high
        }
    }

    static func variantIndex(forQuestID questID: UUID) -> Int {
        withUnsafeBytes(of: questID.uuid) { bytes in
            bytes.reduce(0) { ($0 + Int($1)) % 3 }
        }
    }

    static func monster(forMobLevel level: Int, questID: UUID) -> MonsterKind {
        let index = variantIndex(forQuestID: questID)
        let variants: [MonsterKind]
        switch family(forMobLevel: level) {
        case .low: variants = [.slime, .bat, .mushroom]
        case .medium: variants = [.skeleton, .orc, .mimic]
        case .high: variants = [.dragon, .golem, .lich]
        }
        return variants[index]
    }
}
