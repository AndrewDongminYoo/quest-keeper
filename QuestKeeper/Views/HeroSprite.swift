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

    var body: some View {
        DungeonArtworkView(
            artwork: isMourning ? .heroMourning : .heroIdle,
            size: size
        )
        .scaleEffect(reduceMotion ? 1 : isMourning ? 0.92 : 1)
        .rotationEffect(.degrees(reduceMotion ? 0 : isMourning ? 4 : 0))
        .offset(y: reduceMotion ? 0 : isMourning ? size * 0.08 : 0)
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: isMourning)
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
