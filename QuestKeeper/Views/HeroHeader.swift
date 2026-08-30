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
    var appearance: HeroAppearance = .default
    var onEditAppearance: () -> Void = {}
    var onOpenAbout: () -> Void = {}
    var onOpenHallOfFame: () -> Void = {}

    @ScaledMetric(relativeTo: .caption) private var heroSize: CGFloat = 36
    @ScaledMetric(relativeTo: .caption) private var aboutIconSize: CGFloat = 20
    private let statTapInset: CGFloat = 15

    /// 스프라이트가 44pt 최소 터치 타깃보다 작을 때 채워야 할 한쪽 여백.
    /// Dynamic Type으로 스프라이트가 44pt를 넘으면 0이 되어 패딩이 뒤집히지 않는다.
    private var appearanceTapInset: CGFloat { max(0, (44 - heroSize) / 2) }
    private var aboutTapInset: CGFloat { max(0, (44 - aboutIconSize) / 2) }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                hero
                stats
                Spacer(minLength: 0)
                aboutButton
            }
            VStack(alignment: .leading, spacing: 10) {
                hero
                HStack(spacing: 14) {
                    stats
                    Spacer(minLength: 0)
                    aboutButton
                }
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

    // HUD 오른쪽 끝. 스프라이트가 이미 외형 편집 진입점이라, 그 옆에 두면
    // 두 번째 외형 버튼으로 읽힌다.
    // ponytail: SF Symbol placeholder — 픽셀 아이콘 세트에 info 계열이 없다.
    // 다른 아이콘처럼 icon-about.imageset 을 그리면 교체한다.
    private var aboutButton: some View {
        Button(action: onOpenAbout) {
            Image(systemName: "info.circle")
                .font(.system(size: aboutIconSize))
                .padding(aboutTapInset)
        }
        .contentShape(Rectangle())
        .padding(-aboutTapInset)
        .buttonStyle(.plain)
        .foregroundStyle(DungeonPalette.ink.opacity(0.6))
        // Button 은 감싼 뷰의 접근성 라벨을 대체하므로, 라벨과 힌트를 직접 나눠 붙인다.
        .accessibilityLabel(AppStrings.resolve(AppStrings.heroHeaderAboutButtonAccessibility, locale: .current))
        .accessibilityHint(AppStrings.resolve(AppStrings.heroHeaderAboutButtonHint, locale: .current))
        .accessibilityIdentifier("aboutButton")
    }

    // 승리만 남는다. 진행 중 퀘스트 수는 바로 아래 목록이 이미 말하고 있어 지웠다 — DESIGN.md HUD.
    private var stats: some View {
        Button(action: onOpenHallOfFame) {
            HeroStat(
                icon: .victoryTrophy,
                label: AppStrings.resolve(AppStrings.heroStatVictoryLabel, locale: .current),
                value: state.totalVictories
            )
            .padding(.vertical, statTapInset)
        }
        .contentShape(Rectangle())
        .padding(.vertical, -statTapInset)
        .buttonStyle(.plain)
        .accessibilityLabel(AppStrings.resolve(AppStrings.hallOfFameOpenAccessibility, locale: .current))
        .accessibilityValue("\(state.totalVictories)")
        .accessibilityHint(AppStrings.resolve(AppStrings.hallOfFameOpenHint, locale: .current))
        .accessibilityIdentifier("hallOfFameButton")
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
    }
}

#Preview {
    HeroHeader(
        state: HeroState(totalVictories: 13, dailyGraves: [], deathsWhileAway: [], escalationsWhileAway: []),
        isMourning: false
    )
    .padding()
    .background(DungeonPalette.stone)
}
