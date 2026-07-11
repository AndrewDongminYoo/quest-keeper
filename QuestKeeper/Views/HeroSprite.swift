//
//  HeroSprite.swift
//  QuestKeeper
//
//  Phase 2 — minimal two-state hero. Real pixel art is deferred (spec 003 §5);
//  the contract is the swap driven by `isMourning`, not the art. SF Symbols stand in for frames.
//

import SwiftUI

struct HeroSprite: View {
    let isMourning: Bool

    var body: some View {
        Image(systemName: isMourning ? "figure.fall" : "figure.stand")
            .font(.system(size: 64))
            .foregroundStyle(isMourning ? DungeonPalette.grave : DungeonPalette.hero)
            .contentTransition(.symbolEffect(.replace))
            .frame(height: 80)
            .accessibilityLabel(isMourning ? "쓰러진 용사" : "용사")
    }
}

#Preview {
    VStack(spacing: 40) {
        HeroSprite(isMourning: false)
        HeroSprite(isMourning: true)
    }
}
