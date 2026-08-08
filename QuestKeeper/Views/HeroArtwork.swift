import SwiftUI

nonisolated enum HeroFrame: String, CaseIterable, Sendable {
    case idle
    case breatheIn = "breathe-in"
    case breatheOut = "breathe-out"
    case windUp = "wind-up"
    case strike
}

nonisolated enum HeroArtwork {
    static func assetName(appearance: HeroAppearance, frame: HeroFrame) -> String {
        "sprite-hero-\(appearance.gender.rawValue)-\(appearance.hairColor.rawValue)-\(frame.rawValue)"
    }
}

nonisolated enum HeroAnimation {
    static let breathingFrames: [HeroFrame] = [.idle, .breatheIn, .breatheOut, .breatheIn]

    static func frame(reduceMotion: Bool, frameIndex: Int) -> HeroFrame {
        reduceMotion ? .idle : breathingFrames[frameIndex % breathingFrames.count]
    }
}

struct HeroArtworkView: View {
    let appearance: HeroAppearance
    let frame: HeroFrame
    let size: CGFloat

    var body: some View {
        Image(decorative: HeroArtwork.assetName(appearance: appearance, frame: frame))
            .resizable()
            .interpolation(.none)
            .scaledToFit()
            .frame(width: size, height: size)
    }
}
