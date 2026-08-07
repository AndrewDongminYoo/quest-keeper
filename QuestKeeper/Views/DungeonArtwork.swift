import SwiftUI

nonisolated enum DungeonArtwork: String, CaseIterable, Sendable {
    case heroIdle = "sprite-hero-idle"
    case heroBreatheIn = "sprite-hero-breathe-in"
    case heroBreatheOut = "sprite-hero-breathe-out"
    case heroMourning = "sprite-hero-mourning"
    case slime = "sprite-slime"
    case bat = "sprite-bat"
    case mushroom = "sprite-mushroom"
    case skeleton = "sprite-skeleton"
    case orc = "sprite-orc"
    case mimic = "sprite-mimic"
    case dragon = "sprite-dragon"
    case golem = "sprite-golem"
    case lich = "sprite-lich"
    case dailyGrave = "sprite-daily-grave"
    case victoryReward = "sprite-victory-reward"
    case battleImpact = "sprite-battle-impact"
    case battleFlag = "icon-battle-flag"
    case victoryTrophy = "icon-victory-trophy"
    case notificationsDisabled = "icon-notifications-disabled"
    case retry = "icon-retry"
    case complete = "icon-complete"
    case delete = "icon-delete"

    var contentScale: CGFloat {
        switch self {
        case .battleFlag, .victoryTrophy, .notificationsDisabled, .retry, .complete, .delete:
            1.5
        default:
            1
        }
    }

    static func monster(level: Int, questID: UUID) -> DungeonArtwork {
        switch MonsterArtworkSelection.monster(forMobLevel: level, questID: questID) {
        case .slime: .slime
        case .bat: .bat
        case .mushroom: .mushroom
        case .skeleton: .skeleton
        case .orc: .orc
        case .mimic: .mimic
        case .dragon: .dragon
        case .golem: .golem
        case .lich: .lich
        }
    }
}

struct DungeonArtworkView: View {
    let artwork: DungeonArtwork
    let size: CGFloat

    var body: some View {
        Image(decorative: artwork.rawValue)
            .resizable()
            .interpolation(.none)
            .scaledToFit()
            .frame(width: size, height: size)
            .scaleEffect(artwork.contentScale)
    }
}
