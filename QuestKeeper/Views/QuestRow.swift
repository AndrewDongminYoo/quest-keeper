//
//  QuestRow.swift
//  QuestKeeper
//
//  Phase 2 — presentational rows. A pending quest shows a live countdown and mob level;
//  a grave shows a tombstone and is offered no actions by the enclosing section.
//

import SwiftUI

/// A pending quest. Countdown/mob level derive from `now`, which the enclosing TimelineView advances.
struct QuestRow: View {
    let quest: Quest
    let now: Date

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(quest.title)
                Text(countdown)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            MobLevelBadge(level: quest.snapshot.mobLevel(at: now))
        }
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

/// A grave — read-only record. No swipe actions (undeletable) are attached by the section.
struct GraveRow: View {
    let quest: Quest

    var body: some View {
        Label {
            Text(quest.title)
                .strikethrough()
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: "cross.fill")
                .foregroundStyle(.secondary)
        }
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

    private var tint: Color {
        switch level {
        case ..<2: .green
        case 2..<4: .orange
        default: .red
        }
    }
}
