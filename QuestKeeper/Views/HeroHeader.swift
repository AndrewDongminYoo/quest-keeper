//
//  HeroHeader.swift
//  QuestKeeper
//
//  Phase 2 — hero sprite plus the daily dungeon HUD. Rendered from a derived HeroState.
//

import SwiftUI

struct HeroHeader: View {
    let state: HeroState
    let isMourning: Bool

    var body: some View {
        VStack(spacing: 12) {
            Text("QUEST KEEPER")
                .font(.title.bold().monospaced())
                .foregroundStyle(.white)
            HeroSprite(isMourning: isMourning)
            HStack(spacing: 12) {
                Text("HERO: Leo")
                Text("|")
                    .foregroundStyle(.secondary)
                Label("\(state.totalVictories)", systemImage: "trophy.fill")
                    .foregroundStyle(.yellow)
                    .accessibilityLabel("승리 \(state.totalVictories)")
            }
            .font(.caption.bold().monospacedDigit())
            .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
}

#Preview {
    List {
        HeroHeader(state: HeroState(totalVictories: 3, dailyGraves: [], deathsWhileAway: []), isMourning: false)
    }
}
