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
    var appearance: HeroAppearance = .default
    var onEditAppearance: () -> Void = {}

    @ScaledMetric(relativeTo: .caption) private var heroSize: CGFloat = 36

    /// 스프라이트가 44pt 최소 터치 타깃보다 작을 때 채워야 할 한쪽 여백.
    /// Dynamic Type으로 스프라이트가 44pt를 넘으면 0이 되어 패딩이 뒤집히지 않는다.
    private var appearanceTapInset: CGFloat { max(0, (44 - heroSize) / 2) }

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
            // 스프라이트 자체가 외형 편집 진입점이다. 라벨 텍스트를 두면 한국어(외형)와
            // 영어(Appearance)의 폭 차이가 커서 HUD 한 줄이 무너진다.
            Button(action: onEditAppearance) {
                // 터치 영역은 44pt를 지키되, 바깥의 음수 패딩으로 레이아웃 폭은
                // 스프라이트 크기로 되돌린다. 그러지 않으면 옆의 라벨이 밀려난다.
                HeroSprite(isMourning: isMourning, appearance: appearance, size: heroSize)
                    .padding(appearanceTapInset)
            }
            .contentShape(Rectangle())
            .padding(-appearanceTapInset)
            .buttonStyle(.plain)
            .accessibilityLabel(AppStrings.resolve(AppStrings.heroHeaderAppearanceButtonAccessibility, locale: .current))
            .accessibilityIdentifier("heroAppearanceButton")
            // 스프라이트 애니메이션은 Reduce Motion에서 꺼진다.
            // 그래서 애도 상태는 이 텍스트가 직접 드러낸다.
            Text(isMourning ? AppStrings.heroLabelFallen : AppStrings.heroLabelDefault)
                .foregroundStyle(DungeonPalette.ink)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var stats: some View {
        HStack(spacing: 14) {
            HeroStat(
                icon: .battleFlag,
                label: AppStrings.resolve(AppStrings.heroStatBattleLabel, locale: .current),
                value: activeQuestCount
            )
            HeroStat(
                icon: .victoryTrophy,
                label: AppStrings.resolve(AppStrings.heroStatVictoryLabel, locale: .current),
                value: state.totalVictories
            )
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
            Text(verbatim: "\(value)")
                .foregroundStyle(DungeonPalette.ink)
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .combine)
        // label은 이미 해석된 문자열이고 value는 숫자다. 보간된 리터럴을 그대로 넘기면
        // LocalizedStringKey로 잡혀 카탈로그에 "%@ %lld"가 추출된다.
        .accessibilityLabel(Text(verbatim: "\(label) \(value)"))
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
