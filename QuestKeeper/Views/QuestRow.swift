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
                    .foregroundStyle(isDefeated ? .white.opacity(0.58) : .white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Text(DungeonPresentation.countdownText(deadline: quest.deadline, now: now))
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(isDefeated ? Color.white.opacity(0.48) : tone.tint)
                    ImportancePip(importance: quest.importance)
                }
            }
            Spacer(minLength: 10)
            VStack(alignment: .trailing, spacing: 8) {
                if battlePhase == .defeated {
                    Text("VICTORY +1")
                        .font(.caption2.monospaced().weight(.black))
                        .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.35))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.22), in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                } else {
                    MobLevelBadge(level: level)
                }
                MonsterGlyph(level: level, battlePhase: battlePhase)
            }
        }
        .padding(14)
        .frame(minHeight: 92)
        .background(Color(red: 0.20, green: 0.20, blue: 0.27), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(tone.tint.opacity(0.38), lineWidth: 1)
        )
    }
}

/// A daily grave — temporary presentation with recovery action.
struct DailyGraveRow: View {
    let quest: Quest
    let isNewlyMissed: Bool
    let onRetryTomorrow: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isNewlyMissed ? "exclamationmark.triangle.fill" : "xmark.seal.fill")
                .font(.title2)
                .foregroundStyle(isNewlyMissed ? Color(red: 1.0, green: 0.78, blue: 0.38) : Color(red: 0.66, green: 0.67, blue: 0.66))
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 6) {
                Text(quest.title)
                    .font(.body.weight(.bold))
                    .strikethrough()
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(2)
                Text(isNewlyMissed ? "방금 놓친 전투" : "오늘의 무덤")
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(isNewlyMissed ? Color(red: 1.0, green: 0.78, blue: 0.38) : Color(red: 0.70, green: 0.72, blue: 0.71))
            }
            Spacer(minLength: 10)
            Button(action: onRetryTomorrow) {
                Label("내일 도전하기", systemImage: "arrow.uturn.forward")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(14)
        .frame(minHeight: 92)
        .background(
            (isNewlyMissed ? Color(red: 0.24, green: 0.18, blue: 0.17) : Color(red: 0.17, green: 0.17, blue: 0.22)),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isNewlyMissed ? Color(red: 1.0, green: 0.78, blue: 0.38).opacity(0.58) : Color(red: 0.55, green: 0.57, blue: 0.56).opacity(0.35),
                    lineWidth: 1
                )
        )
        .accessibilityValue(isNewlyMissed ? "방금 놓친 전투" : "")
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
            .background(Color.white.opacity(0.10), in: Capsule())
            .foregroundStyle(.white.opacity(0.72))
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
    let battlePhase: QuestBattlePhase

    init(level: Int, battlePhase: QuestBattlePhase = .idle) {
        self.level = level
        self.battlePhase = battlePhase
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.title3)
            .foregroundStyle(tint)
            .frame(width: 28, height: 28)
            .scaleEffect(battlePhase == .striking ? 1.22 : battlePhase == .defeated ? 0.82 : 1)
            .rotationEffect(.degrees(battlePhase == .striking ? -8 : battlePhase == .defeated ? 10 : 0))
            .opacity(battlePhase == .defeated ? 0.35 : 1)
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

private extension DungeonUrgencyTone {
    var tint: Color {
        switch self {
        case .calm: Color(red: 0.46, green: 0.86, blue: 0.62)
        case .warning: Color(red: 1.0, green: 0.70, blue: 0.29)
        case .danger: Color(red: 1.0, green: 0.43, blue: 0.35)
        }
    }
}
