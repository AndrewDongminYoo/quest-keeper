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
    let heroAppearance: HeroAppearance
    let battlePhase: QuestBattlePhase
    let guidanceText: String?
    let isCompleted: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        quest: Quest,
        now: Date,
        heroAppearance: HeroAppearance = .default,
        battlePhase: QuestBattlePhase = .idle,
        guidanceText: String? = nil,
        isCompleted: Bool = false
    ) {
        self.quest = quest
        self.now = now
        self.heroAppearance = heroAppearance
        self.battlePhase = battlePhase
        self.guidanceText = guidanceText
        self.isCompleted = isCompleted
    }

    var body: some View {
        let level = quest.snapshot.mobLevel(at: now)
        let tone = DungeonPresentation.urgencyTone(deadline: quest.deadline, mobLevel: level, now: now)
        let monsterKind = MonsterArtworkSelection.monster(forMobLevel: level, questID: quest.id)
        let isDefeated = battlePhase == .defeated
        let tint = isCompleted ? DungeonPalette.victory : tone.tint

        HStack(spacing: 12) {
            DungeonLaneMarker(tint: tint)
            VStack(alignment: .leading, spacing: 8) {
                Text(quest.title)
                    .font(.body.weight(.bold))
                    .foregroundStyle(isDefeated || isCompleted ? DungeonPalette.ink.opacity(0.58) : DungeonPalette.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let guidanceText {
                    Text(guidanceText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DungeonPalette.hero)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !isCompleted {
                    HStack(spacing: 8) {
                        Text(DungeonPresentation.countdownText(deadline: quest.deadline, now: now))
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(isDefeated ? DungeonPalette.ink.opacity(0.48) : tone.tint)
                        ImportancePip(importance: quest.importance)
                    }
                }
            }
            Spacer(minLength: 10)
            Group {
                if battlePhase == .idle || isCompleted {
                    VStack(alignment: .trailing, spacing: 8) {
                        if isCompleted {
                            HStack(spacing: 4) {
                                DungeonArtworkView(artwork: .victoryReward, size: 14)
                                Text(AppStrings.questActionComplete)
                                    .accessibilityLabel(AppStrings.resolve(AppStrings.a11yQuestComplete(quest.title), locale: .current))
                            }
                            .font(.caption2.weight(.black))
                            .foregroundStyle(DungeonPalette.victory)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 2))
                        } else {
                            MobLevelBadge(level: level)
                        }
                        MonsterGlyph(level: level, questID: quest.id)
                    }
                } else {
                    QuestBattleScene(
                        appearance: heroAppearance,
                        monster: .monster(level: level, questID: quest.id),
                        monsterKind: monsterKind,
                        monsterLevel: level,
                        phase: battlePhase
                    )
                    .transition(reduceMotion ? .identity : .opacity)
                }
            }
            .frame(width: 100, alignment: .trailing)
        }
        .padding(14)
        .frame(minHeight: 92)
        .background(DungeonPalette.stone, in: RoundedRectangle(cornerRadius: 2))
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .stroke(tint.opacity(0.45), lineWidth: 2)  // chunky pixel border
        )
        .accessibilityHint(guidanceText ?? "")
        .accessibilityValue(isCompleted ? AppStrings.resolve(AppStrings.questStateCompleted, locale: .current) : "")
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
            DungeonArtworkView(artwork: .dailyGrave, size: 34)
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
                Label(AppStrings.questActionRetryTomorrow, systemImage: "arrow.uturn.forward")
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
        let caption: String
        let captionTint: Color
        let background: Color
        let borderTint: Color
        /// Non-visual cue for the mourning state; empty for a plain grave (color is not the only signal).
        let accessibilityValue: String

        // A just-missed grave wears the warm `torch` alarm; an older grave settles into muted `grave`.
        // `static var`, not `static let` — resolving the locale at every access instead of caching it
        // once for the process lifetime, matching the "derive at read time" convention everywhere else
        // this diff touches (e.g. `BoardSectionTitle` re-resolving on every `body` pass).
        static var mourning: Style {
            Style(
                caption: AppStrings.resolve(AppStrings.questGraveJustMissed, locale: .current),
                captionTint: DungeonPalette.torch,
                background: DungeonPalette.stone,
                borderTint: DungeonPalette.torch.opacity(0.58),
                accessibilityValue: AppStrings.resolve(AppStrings.questGraveJustMissed, locale: .current)
            )
        }

        static var rest: Style {
            Style(
                caption: AppStrings.resolve(AppStrings.dungeonGraveTitle, locale: .current),
                captionTint: DungeonPalette.grave,
                background: DungeonPalette.stone,
                borderTint: DungeonPalette.grave.opacity(0.35),
                accessibilityValue: ""
            )
        }
    }
}

private struct DungeonLaneMarker: View {
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(tint)
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
    let questID: UUID
    let battlePhase: QuestBattlePhase

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(level: Int, questID: UUID, battlePhase: QuestBattlePhase = .idle) {
        self.level = level
        self.questID = questID
        self.battlePhase = battlePhase
    }

    var body: some View {
        ZStack {
            if battlePhase == .striking {
                DungeonArtworkView(artwork: .battleImpact, size: 34)
                    .transition(.opacity)
            }
            DungeonArtworkView(artwork: .monster(level: level, questID: questID), size: 30)
        }
        .frame(width: 34, height: 34)
        .scaleEffect(reduceMotion ? 1 : battlePhase == .striking ? 1.22 : battlePhase == .defeated ? 0.82 : 1)
        .rotationEffect(.degrees(reduceMotion ? 0 : battlePhase == .striking ? -8 : battlePhase == .defeated ? 10 : 0))
        .opacity(battlePhase == .defeated ? 0.35 : 1)
        .transaction { transaction in
            if reduceMotion {
                transaction.animation = nil
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            AppStrings.resolve(
                AppStrings.a11yMonsterLevel(
                    MonsterArtworkSelection.monster(forMobLevel: level, questID: questID).localizedName(),
                    level
                ),
                locale: .current
            )
        )
    }
}
