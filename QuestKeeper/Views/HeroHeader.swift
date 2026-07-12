//
//  HeroHeader.swift
//  QuestKeeper
//
//  Phase 2 — the compact daily-dungeon stat line. Rendered from a derived HeroState.
//  DESIGN.md HUD: hero label + total victories + optional active-quest count — kept to one line,
//  monospaced, so the dungeon floors below stay the primary surface.
//

import SwiftUI

struct HeroHeader: View {
    let state: HeroState
    let isMourning: Bool
    let activeQuestCount: Int

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 5) {
                HeroSprite(isMourning: isMourning, size: 20)
                Text("용사")
                    .foregroundStyle(DungeonPalette.ink)
            }
            HeroStat(icon: "flag.checkered", label: "전투", value: activeQuestCount, tint: DungeonPalette.hero)
            HeroStat(icon: "trophy.fill", label: "승리", value: state.totalVictories, tint: DungeonPalette.victory)
            Spacer(minLength: 0)
        }
        .font(.caption.bold().monospacedDigit())
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A single compact HUD stat: a state-tinted icon, a Korean label, and a monospaced count.
private struct HeroStat: View {
    let icon: String
    let label: String
    let value: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(label)
                .foregroundStyle(DungeonPalette.ink.opacity(0.7))
            Text("\(value)")
                .foregroundStyle(DungeonPalette.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }
}

#Preview {
    HeroHeader(
        state: HeroState(totalVictories: 13, dailyGraves: [], deathsWhileAway: []),
        isMourning: false,
        activeQuestCount: 3
    )
    .padding()
    .background(DungeonPalette.stone)
}
