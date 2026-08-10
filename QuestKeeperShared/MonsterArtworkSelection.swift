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

    func localizedName(locale: Locale = .current) -> String {
        var resource = SharedStrings.monsterName(self)
        resource.locale = locale
        return String(localized: resource)
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

    /// The single source of truth for which monsters a family can render — the explanation
    /// sheet lists these, so a swap here cannot leave the sheet describing the wrong monster.
    static func variants(for family: MonsterFamily) -> [MonsterKind] {
        switch family {
        case .low: [.slime, .bat, .mushroom]
        case .medium: [.skeleton, .orc, .mimic]
        case .high: [.dragon, .golem, .lich]
        }
    }

    static func monster(forMobLevel level: Int, questID: UUID) -> MonsterKind {
        variants(for: family(forMobLevel: level))[variantIndex(forQuestID: questID)]
    }
}
