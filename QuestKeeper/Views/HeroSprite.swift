//
//  HeroSprite.swift
//  QuestKeeper
//
//  Phase 2 / DESIGN.md step 5 — a small drawn pixel hero. The contract is the state swap driven
//  by `isMourning`: standing (hero-tinted) vs knocked over (grave-tinted, rotated). One bitmap
//  serves both; only color and rotation change.
//
//  It is an inline HUD glyph, not a centerpiece: the dungeon floors (quest rows) are the primary
//  surface per DESIGN.md, so the hero stays small and only its state carries meaning.
//

import SwiftUI

struct HeroSprite: View {
    let isMourning: Bool
    var size: CGFloat = 22

    var body: some View {
        PixelSprite(
            rows: DungeonSprites.hero,
            palette: [
                "#": isMourning ? DungeonPalette.grave : DungeonPalette.hero,
                "o": DungeonPalette.stone
            ]
        )
        .frame(width: size, height: size)
        .rotationEffect(.degrees(isMourning ? 90 : 0))  // knocked over on a mourning activation
        .animation(.snappy(duration: 0.25), value: isMourning)
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
