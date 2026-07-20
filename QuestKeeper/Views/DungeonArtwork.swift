import SwiftUI

nonisolated enum DungeonArtwork: String, CaseIterable, Sendable {
    case heroIdle = "sprite-hero-idle"
    case heroBreatheIn = "sprite-hero-breathe-in"
    case heroBreatheOut = "sprite-hero-breathe-out"
    case heroMourning = "sprite-hero-mourning"
    case slime = "sprite-slime"
    case skeleton = "sprite-skeleton"
    case dragon = "sprite-dragon"
    case dailyGrave = "sprite-daily-grave"
    case victoryReward = "sprite-victory-reward"
    case battleImpact = "sprite-battle-impact"
    case battleFlag = "icon-battle-flag"
    case victoryTrophy = "icon-victory-trophy"
    case add = "icon-add"
    case notificationsDisabled = "icon-notifications-disabled"
    case retry = "icon-retry"
    case complete = "icon-complete"
    case delete = "icon-delete"

    static func monster(level: Int) -> DungeonArtwork {
        switch level {
        case ..<2: .slime
        case 2..<4: .skeleton
        default: .dragon
        }
    }
}

nonisolated enum HeroAnimation {
    static let breathingFrames: [DungeonArtwork] = [
        .heroIdle,
        .heroBreatheIn,
        .heroBreatheOut,
        .heroBreatheIn,
    ]

    static func artwork(isMourning: Bool, reduceMotion: Bool, frameIndex: Int) -> DungeonArtwork {
        if isMourning {
            return .heroMourning
        }
        guard !reduceMotion else {
            return .heroIdle
        }
        return breathingFrames[frameIndex % breathingFrames.count]
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
    }
}
