//
//  HeroHeader.swift
//  QuestKeeper
//
//  Phase 2 — hero sprite plus the victory/grave scoreboard. Rendered from a derived HeroState.
//

import SwiftUI

struct HeroHeader: View {
    let state: HeroState
    let isMourning: Bool

    var body: some View {
        VStack(spacing: 12) {
            HeroSprite(isMourning: isMourning)
            HStack(spacing: 32) {
                tally(state.victories, symbol: "trophy.fill", tint: .yellow, label: "승리")
                tally(state.graves, symbol: "cross.fill", tint: .secondary, label: "무덤")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .listRowSeparator(.hidden)
    }

    private func tally(_ count: Int, symbol: String, tint: Color, label: String) -> some View {
        VStack(spacing: 4) {
            Label("\(count)", systemImage: symbol)
                .font(.title3.monospacedDigit())
                .foregroundStyle(tint)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(count)")
    }
}

#Preview {
    List {
        HeroHeader(state: HeroState(victories: 3, graves: 1, deathsWhileAway: []), isMourning: false)
    }
}
