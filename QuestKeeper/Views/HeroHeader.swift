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

    @ScaledMetric(relativeTo: .caption) private var heroSize: CGFloat = 20

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                hero
                stats
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 10) {
                hero
                stats
            }
        }
        .font(.caption.bold().monospacedDigit())
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var hero: some View {
        HStack(spacing: 5) {
            HeroSprite(isMourning: isMourning, size: heroSize)
            Text("용사")
                .foregroundStyle(DungeonPalette.ink)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var stats: some View {
        HStack(spacing: 14) {
            HeroStat(icon: .battleFlag, label: "전투", value: activeQuestCount)
            HeroStat(icon: .victoryTrophy, label: "승리", value: state.totalVictories)
        }
    }
}

private struct HeroStat: View {
    let icon: DungeonArtwork
    let label: String
    let value: Int

    var body: some View {
        HStack(spacing: 4) {
            DungeonArtworkView(artwork: icon, size: 14)
            Text(label)
                .foregroundStyle(DungeonPalette.ink.opacity(0.7))
            Text("\(value)")
                .foregroundStyle(DungeonPalette.ink)
        }
        .fixedSize(horizontal: true, vertical: false)
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
