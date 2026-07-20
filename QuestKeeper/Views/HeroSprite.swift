//
//  HeroSprite.swift
//  QuestKeeper
//
//  It is an inline HUD glyph, not a centerpiece: the dungeon floors (quest rows) are the primary
//  surface per DESIGN.md, so the hero stays small and only its state carries meaning.
//

import SwiftUI

struct HeroSprite: View {
    let isMourning: Bool
    var size: CGFloat = 22

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var frameIndex = 0

    private var shouldBreathe: Bool {
        !isMourning && !reduceMotion
    }

    private var artwork: DungeonArtwork {
        HeroAnimation.artwork(
            isMourning: isMourning,
            reduceMotion: reduceMotion,
            frameIndex: frameIndex
        )
    }

    var body: some View {
        DungeonArtworkView(
            artwork: artwork,
            size: size
        )
        .scaleEffect(reduceMotion ? 1 : isMourning ? 0.92 : 1)
        .rotationEffect(.degrees(reduceMotion ? 0 : isMourning ? 4 : 0))
        .offset(y: reduceMotion ? 0 : isMourning ? size * 0.08 : 0)
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: isMourning)
        .task(id: shouldBreathe) {
            frameIndex = 0
            guard shouldBreathe else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }
                frameIndex = (frameIndex + 1) % HeroAnimation.breathingFrames.count
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isMourning ? "쓰러진 용사" : "용사")
    }
}

#Preview {
    HStack(spacing: 24) {
        HeroSprite(isMourning: false, size: 64)
        HeroSprite(isMourning: true, size: 64)
    }
    .padding()
    .background(DungeonPalette.stone)
}
