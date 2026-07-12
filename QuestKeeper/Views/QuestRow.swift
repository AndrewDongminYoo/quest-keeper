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
    let battlePhase: QuestBattlePhase

    init(quest: Quest, now: Date, battlePhase: QuestBattlePhase = .idle) {
        self.quest = quest
        self.now = now
        self.battlePhase = battlePhase
    }

    var body: some View {
        let level = quest.snapshot.mobLevel(at: now)
        let tone = DungeonPresentation.urgencyTone(deadline: quest.deadline, mobLevel: level, now: now)
        let isDefeated = battlePhase == .defeated

        HStack(spacing: 12) {
            DungeonLaneMarker(tone: tone)
            VStack(alignment: .leading, spacing: 8) {
                Text(quest.title)
                    .font(.body.weight(.bold))
                    .foregroundStyle(isDefeated ? DungeonPalette.ink.opacity(0.58) : DungeonPalette.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Text(DungeonPresentation.countdownText(deadline: quest.deadline, now: now))
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(isDefeated ? DungeonPalette.ink.opacity(0.48) : tone.tint)
                    ImportancePip(importance: quest.importance)
                }
            }
            Spacer(minLength: 10)
            VStack(alignment: .trailing, spacing: 8) {
                if battlePhase == .defeated {
                    Text("VICTORY +1")
                        .font(.caption2.monospaced().weight(.black))
                        .foregroundStyle(DungeonPalette.victory)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 2))
                        .transition(.scale.combined(with: .opacity))
                } else {
                    MobLevelBadge(level: level)
                }
                MonsterGlyph(level: level, battlePhase: battlePhase)
            }
        }
        .padding(14)
        .frame(minHeight: 92)
        .background(DungeonPalette.stone, in: RoundedRectangle(cornerRadius: 2))
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .stroke(tone.tint.opacity(0.45), lineWidth: 2)  // chunky pixel border
        )
    }
}

/// A daily grave — temporary presentation with recovery action.
struct DailyGraveRow: View {
    let quest: Quest
    let isNewlyMissed: Bool
    let onRetryTomorrow: () -> Void

    private var style: Style { isNewlyMissed ? .mourning : .rest }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: style.icon)
                .font(.title2)
                .foregroundStyle(style.iconTint)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 6) {
                Text(quest.title)
                    .font(.body.weight(.bold))
                    .strikethrough()
                    .foregroundStyle(DungeonPalette.ink.opacity(0.62))
                    .lineLimit(2)
                Text(style.caption)
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(style.captionTint)
            }
            Spacer(minLength: 10)
            Button(action: onRetryTomorrow) {
                Label("내일 도전하기", systemImage: "arrow.uturn.forward")
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
                    .fixedSize()
            }
            .buttonStyle(.pixel)
        }
        .padding(14)
        .frame(minHeight: 92)
        .background(style.background, in: RoundedRectangle(cornerRadius: 2))
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .stroke(style.borderTint, lineWidth: 2)  // chunky pixel border
        )
        .accessibilityValue(style.accessibilityValue)
    }
}

private extension DailyGraveRow {
    /// Visual variant of a grave row. Newly-missed quests wear the mourning treatment
    /// during the transient `pendingDeaths` window; older graves fall back to the rest palette.
    struct Style {
        let icon: String
        let iconTint: Color
        let caption: String
        let captionTint: Color
        let background: Color
        let borderTint: Color
        /// Non-visual cue for the mourning state; empty for a plain grave (color is not the only signal).
        let accessibilityValue: String

        // A just-missed grave wears the warm `torch` alarm; an older grave settles into muted `grave`.
        static let mourning = Style(
            icon: "exclamationmark.triangle.fill",
            iconTint: DungeonPalette.torch,
            caption: "방금 놓친 전투",
            captionTint: DungeonPalette.torch,
            background: DungeonPalette.stone,
            borderTint: DungeonPalette.torch.opacity(0.58),
            accessibilityValue: "방금 놓친 전투"
        )

        static let rest = Style(
            icon: "xmark.seal.fill",
            iconTint: DungeonPalette.grave,
            caption: "오늘의 무덤",
            captionTint: DungeonPalette.grave,
            background: DungeonPalette.stone,
            borderTint: DungeonPalette.grave.opacity(0.35),
            accessibilityValue: ""
        )
    }
}

private struct DungeonLaneMarker: View {
    let tone: DungeonUrgencyTone

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(tone.tint)
            .frame(width: 5, height: 58)
    }
}

private struct ImportancePip: View {
    let importance: Importance

    var body: some View {
        Text("IMP \(importance.rawValue)")
            .font(.caption2.weight(.black))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(DungeonPalette.ink.opacity(0.10), in: RoundedRectangle(cornerRadius: 2))
            .foregroundStyle(DungeonPalette.ink.opacity(0.72))
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
            .background(tint.opacity(0.2), in: RoundedRectangle(cornerRadius: 2))
            .foregroundStyle(tint)
    }

    private var tint: Color { MobVisual.tint(level: level) }
}

struct MonsterGlyph: View {
    let level: Int
    let battlePhase: QuestBattlePhase

    init(level: Int, battlePhase: QuestBattlePhase = .idle) {
        self.level = level
        self.battlePhase = battlePhase
    }

    var body: some View {
        PixelSprite(
            rows: DungeonSprites.monster(level: level),
            palette: ["#": MobVisual.tint(level: level), "o": DungeonPalette.stone]
        )
        .frame(width: 30, height: 30)
        .scaleEffect(battlePhase == .striking ? 1.22 : battlePhase == .defeated ? 0.82 : 1)
        .rotationEffect(.degrees(battlePhase == .striking ? -8 : battlePhase == .defeated ? 10 : 0))
        .opacity(battlePhase == .defeated ? 0.35 : 1)
        .accessibilityLabel("몹 레벨 \(level)")
    }
}
