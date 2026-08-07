import SwiftUI

struct QuestBattleScene: View {
    let appearance: HeroAppearance
    let monster: DungeonArtwork
    let monsterKind: MonsterKind
    let monsterLevel: Int
    let phase: QuestBattlePhase

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var heroFrame: HeroFrame {
        return switch phase {
        case .idle: .idle
        case .windUp: .windUp
        case .striking, .defeated: .strike
        }
    }

    private var phaseValue: String {
        return switch phase {
        case .idle: ""
        case .windUp: "공격 준비 중"
        case .striking: "공격 중"
        case .defeated: "승리 처리 중"
        }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            HeroArtworkView(appearance: appearance, frame: heroFrame, size: 46)
                .offset(x: heroOffset, y: 1)

            DungeonArtworkView(artwork: monster, size: 38)
                .scaleEffect(monsterScale)
                .rotationEffect(.degrees(monsterRotation))
                .offset(x: monsterOffset, y: -1)
                .opacity(phase == .defeated ? 0.2 : 1)

            if phase == .striking {
                DungeonArtworkView(artwork: .battleImpact, size: 30)
                    .offset(x: 56, y: -8)
            }

            if phase == .defeated {
                DungeonArtworkView(artwork: .victoryReward, size: 18)
                    .offset(x: 78, y: -27)
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
        .accessibilityLabel("\(monsterKind.localizedName) 레벨 \(monsterLevel)")
        .accessibilityValue(phaseValue)
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
        guard !reduceMotion else { return 62 }
        return switch phase {
        case .idle, .windUp: 62
        case .striking: 67
        case .defeated: 71
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
