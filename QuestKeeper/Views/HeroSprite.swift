//
//  HeroSprite.swift
//  QuestKeeper
//
//  Phase 2 — minimal two-state hero glyph. Real pixel art is deferred (spec 003 §5);
//  the contract is the swap driven by `isMourning`, not the art. SF Symbols stand in for frames.
//
//  It is an inline HUD glyph, not a centerpiece: the dungeon floors (quest rows) are the
//  primary surface per DESIGN.md, so the hero stays small and only its state carries meaning.
//

import SwiftUI

struct HeroSprite: View {
    let isMourning: Bool
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: isMourning ? "figure.fall" : "figure.stand")
            .font(.system(size: size, weight: .black))
            .foregroundStyle(isMourning ? DungeonPalette.grave : DungeonPalette.hero)
            .contentTransition(.symbolEffect(.replace))
            .accessibilityLabel(isMourning ? "쓰러진 용사" : "용사")
    }
}

#Preview {
    HStack(spacing: 24) {
        HeroSprite(isMourning: false)
        HeroSprite(isMourning: true)
    }
    .padding()
}
