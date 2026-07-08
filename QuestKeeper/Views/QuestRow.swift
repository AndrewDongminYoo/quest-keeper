//
//  QuestRow.swift
//  QuestKeeper
//
//  Phase 2 — presentational rows. A pending quest shows a live countdown and mob level;
//  a daily grave shows a temporary tombstone plus retry action.
//

import SwiftUI

/// A pending quest. Countdown/mob level derive from `now`, which the enclosing TimelineView advances.
struct QuestRow: View {
    let quest: Quest
    let now: Date

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(quest.title)
                    .font(.body.weight(.semibold))
                Text(countdown)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            MobLevelBadge(level: quest.snapshot.mobLevel(at: now))
            MonsterGlyph(level: quest.snapshot.mobLevel(at: now))
        }
        .padding(.vertical, 6)
    }

    private var countdown: String {
        let remaining = quest.deadline.timeIntervalSince(now)
        guard remaining > 0 else { return "마감 임박" }
        let minutes = Int(remaining) / 60
        if minutes >= 1440 { return "\(minutes / 1440)일 남음" }
        if minutes >= 60 { return "\(minutes / 60)시간 \(minutes % 60)분 남음" }
        return "\(minutes)분 남음"
    }
}

/// A daily grave — temporary presentation with recovery action.
struct DailyGraveRow: View {
    let quest: Quest
    let onRetryTomorrow: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "xmark.seal.fill")
                .foregroundStyle(.gray)
            VStack(alignment: .leading, spacing: 4) {
                Text(quest.title)
                    .strikethrough()
                    .foregroundStyle(.secondary)
                Text("오늘의 무덤")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onRetryTomorrow) {
                Label("내일 도전하기", systemImage: "arrow.uturn.forward")
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 6)
    }
}

/// Discrete mob tier 0…maxMobLevel, tinted by height.
struct MobLevelBadge: View {
    let level: Int

    var body: some View {
        Text("Lv \(level)")
            .font(.caption2.bold().monospacedDigit())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.2), in: Capsule())
            .foregroundStyle(tint)
    }

    private var tint: Color { level.mobLevelTint }
}

private extension Int {
    var mobLevelTint: Color {
        switch self {
        case ..<2: .green
        case 2..<4: .orange
        default: .red
        }
    }
}

struct MonsterGlyph: View {
    let level: Int

    var body: some View {
        Image(systemName: symbol)
            .font(.title3)
            .foregroundStyle(tint)
            .frame(width: 28, height: 28)
            .accessibilityLabel("몹 레벨 \(level)")
    }

    private var symbol: String {
        switch level {
        case ..<2: "circle.hexagongrid.fill"
        case 2..<4: "figure.fencing"
        default: "flame.fill"
        }
    }

    private var tint: Color { level.mobLevelTint }
}
