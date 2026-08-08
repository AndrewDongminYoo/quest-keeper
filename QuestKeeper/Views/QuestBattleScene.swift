import SwiftUI

struct QuestBattleScene: View {
    let appearance: HeroAppearance
    let monster: DungeonArtwork
    let monsterKind: MonsterKind
    let monsterLevel: Int
    let phase: QuestBattlePhase

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            HeroArtworkView(appearance: appearance, frame: QuestBattleResolution.heroFrame(for: phase), size: 60)
                .offset(x: heroOffset, y: 1)

            DungeonArtworkView(artwork: monster, size: 50)
                .scaleEffect(monsterScale)
                .rotationEffect(.degrees(monsterRotation))
                .offset(x: monsterOffset, y: -1)
                .opacity(phase == .defeated ? 0.2 : 1)

            if QuestBattleResolution.showsImpact(for: phase) {
                DungeonArtworkView(artwork: .battleImpact, size: 38)
                    .offset(x: 50, y: -8)
            }

            if QuestBattleResolution.showsVictory(for: phase) {
                HStack(spacing: 2) {
                    DungeonArtworkView(artwork: .victoryReward, size: 16)
                    Text(AppStrings.battleSceneVictoryBanner)
                        .font(.caption2.bold())
                        .foregroundStyle(DungeonPalette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(width: 100, height: 48, alignment: .topTrailing)
            }
        }
        .frame(width: 100, height: 48, alignment: .bottomLeading)
        .clipped()
        .transaction { transaction in
            if reduceMotion {
                transaction.animation = nil
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppStrings.resolve(
            AppStrings.a11yMonsterLevel(monsterKind.localizedName(), monsterLevel),
            locale: .current
        ))
        .accessibilityValue(QuestBattleResolution.accessibilityValue(for: phase))
    }

    private var heroOffset: CGFloat {
        guard !reduceMotion else { return 0 }
        return switch phase {
        case .idle: 0
        case .windUp: -3
        case .striking: 12
        case .defeated: 8
        }
    }

    private var monsterOffset: CGFloat {
        guard !reduceMotion else { return 54 }
        return switch phase {
        case .idle, .windUp: 54
        case .striking: 59
        case .defeated: 63
        }
    }

    private var monsterScale: CGFloat {
        guard !reduceMotion else { return 1 }
        return switch phase {
        case .idle, .windUp: 1
        case .striking: 1.12
        case .defeated: 0.78
        }
    }

    private var monsterRotation: Double {
        guard !reduceMotion else { return 0 }
        return switch phase {
        case .idle, .windUp: 0
        case .striking: -7
        case .defeated: 10
        }
    }
}

#Preview {
    QuestBattleScene(
        appearance: .default,
        monster: .orc,
        monsterKind: .orc,
        monsterLevel: 3,
        phase: .striking
    )
    .padding()
    .background(DungeonPalette.stone)
}
