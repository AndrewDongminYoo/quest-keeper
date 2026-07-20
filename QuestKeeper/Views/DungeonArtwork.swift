import SwiftUI

nonisolated enum DungeonArtwork: String, CaseIterable, Sendable {
    case heroIdle = "sprite-hero-idle"
    case heroMourning = "sprite-hero-mourning"
    case slime = "sprite-slime"
    case skeleton = "sprite-skeleton"
    case dragon = "sprite-dragon"
    case dailyGrave = "sprite-daily-grave"
    case victoryReward = "sprite-victory-reward"
    case battleImpact = "sprite-battle-impact"

    static func monster(level: Int) -> DungeonArtwork {
        switch level {
        case ..<2: .slime
        case 2..<4: .skeleton
        default: .dragon
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
    }
}
