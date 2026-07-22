import SwiftUI

struct HomeDungeonBoardView: View {
    let state: HeroState
    let isMourning: Bool
    let allQuests: [Quest]
    let pending: [Quest]
    let dailyGraves: [Quest]
    let newlyMissedQuestIDs: Set<UUID>
    let now: Date
    let showsNotificationPermissionBanner: Bool
    let onboardingPresentation: OnboardingFlowPresentation
    let dailyFocusPresentation: DailyFocusPresentationState
    let onCreate: () -> Void
    let onStartGuidedQuest: () -> Void
    let onDeferOnboarding: () -> Void
    let onConfirmDailyFocus: ([UUID]) -> Void
    let onEditDailyFocus: ([UUID], DailyFocusSelectionKind) -> Void
    let onOpenNotificationSettings: () -> Void
    let onComplete: (Quest, Date) -> Void
    let onRetryTomorrow: (Quest) -> Void
    let onDelete: (Quest) -> Void
    let onEdit: (Quest) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            DungeonBackground()
            ScrollView {
                LazyVStack(spacing: 14) {
                    BoardHUD(state: state, isMourning: isMourning, activeQuestCount: pending.count, onCreate: onCreate)
                    if showsNotificationPermissionBanner {
                        NotificationPermissionBanner(onOpenSettings: onOpenNotificationSettings)
                    }
                    if onboardingPresentation == .guidedOffer {
                        GuidedOnboardingCard(
                            onStartGuidedQuest: onStartGuidedQuest,
                            onCreate: onCreate,
                            onDefer: onDeferOnboarding
                        )
                    } else if pending.isEmpty && dailyGraves.isEmpty && !dailyFocusPresentation.isConfirmed {
                        EmptyDungeonState(onCreate: onCreate)
                    } else {
                        if case let .recommended(questIDs) = dailyFocusPresentation {
                            DailyFocusRecommendationCard(
                                quests: quests(for: questIDs),
                                onEdit: {
                                    onEditDailyFocus(questIDs, .confirmation)
                                },
                                onConfirm: {
                                    onConfirmDailyFocus(questIDs)
                                }
                            )
                        }
                        QuestListSections(
                            allQuests: allQuests,
                            pending: pending,
                            dailyGraves: dailyGraves,
                            newlyMissedQuestIDs: newlyMissedQuestIDs,
                            guidedCompletionQuestID: onboardingPresentation.guidedCompletionQuestID,
                            dailyFocusQuestIDs: dailyFocusPresentation.selectedQuestIDs,
                            completedDailyFocusQuestIDs: dailyFocusPresentation.completedQuestIDs,
                            onEditDailyFocus: {
                                let pendingSelectedIDs = (dailyFocusPresentation.selectedQuestIDs ?? []).filter { selectedID in
                                    pending.contains(where: { $0.id == selectedID })
                                }
                                onEditDailyFocus(pendingSelectedIDs, .revision)
                            },
                            now: now,
                            onComplete: onComplete,
                            onRetryTomorrow: onRetryTomorrow,
                            onDelete: onDelete,
                            onEdit: onEdit
                        )
                        .animation(.default, value: pending.map(\.id))
                        .animation(.default, value: dailyGraves.map(\.id))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
        }
    }

    private func quests(for questIDs: [UUID]) -> [Quest] {
        let questsByID = Dictionary(uniqueKeysWithValues: allQuests.map { ($0.id, $0) })
        return questIDs.compactMap { questsByID[$0] }
    }
}

private struct DailyFocusRecommendationCard: View {
    let quests: [Quest]
    let onEdit: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("오늘의 핵심 퀘스트")
                .font(.headline.weight(.black))
                .foregroundStyle(DungeonPalette.ink)
            Text("추천을 확인하고 오늘의 전투를 직접 선택하세요.")
                .font(.subheadline)
                .foregroundStyle(DungeonPalette.ink.opacity(0.76))
            VStack(alignment: .leading, spacing: 8) {
                ForEach(quests) { quest in
                    Text("• \(quest.title)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DungeonPalette.ink)
                        .lineLimit(2)
                }
            }
            HStack(spacing: 12) {
                Button("핵심 퀘스트 수정", action: onEdit)
                    .frame(maxWidth: .infinity, minHeight: 44)
                Button("오늘 이대로 시작", action: onConfirm)
                    .buttonStyle(.pixel)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(16)
        .background(DungeonPalette.stone, in: RoundedRectangle(cornerRadius: 2))
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .stroke(DungeonPalette.hero.opacity(0.55), lineWidth: 2)
        )
        .accessibilityElement(children: .contain)
    }
}

private extension DailyFocusPresentationState {
    var isConfirmed: Bool {
        guard case .confirmed = self else { return false }
        return true
    }

    var selectedQuestIDs: [UUID]? {
        guard case let .confirmed(selectedQuestIDs, _) = self else { return nil }
        return selectedQuestIDs
    }

    var completedQuestIDs: Set<UUID> {
        guard case let .confirmed(_, completedQuestIDs) = self else { return [] }
        return completedQuestIDs
    }
}

private struct GuidedOnboardingCard: View {
    let onStartGuidedQuest: () -> Void
    let onCreate: () -> Void
    let onDefer: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("첫 승리를 시작해볼까요?")
                .font(.headline.weight(.black))
                .foregroundStyle(DungeonPalette.ink)
            Text("2분 안에 끝낼 수\u{00A0}있는 작은 전투부터 시작하세요.")
                .font(.subheadline)
                .foregroundStyle(DungeonPalette.ink.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("2분 안에 끝낼 수 있는 작은 전투부터 시작하세요.")
            Button("2분 전투 시작", action: onStartGuidedQuest)
                .buttonStyle(.pixel)
                .frame(maxWidth: .infinity, minHeight: 44)
            HStack(spacing: 12) {
                Button("직접 만들기", action: onCreate)
                    .frame(maxWidth: .infinity, minHeight: 44)
                Button("나중에", action: onDefer)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(DungeonPalette.ink)
        }
        .padding(16)
        .background(DungeonPalette.stone, in: RoundedRectangle(cornerRadius: 2))
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .stroke(DungeonPalette.hero.opacity(0.55), lineWidth: 2)
        )
        .accessibilityElement(children: .contain)
    }
}

private extension OnboardingFlowPresentation {
    var guidedCompletionQuestID: UUID? {
        guard case let .guidedCompletion(questID) = self else { return nil }
        return questID
    }
}

private struct DungeonBackground: View {
    var body: some View {
        // Flat dungeon fill — DESIGN.md: "Do not add decorative glow blobs or gradients as filler."
        DungeonPalette.dungeon
            .ignoresSafeArea()
    }
}

private struct BoardHUD: View {
    let state: HeroState
    let isMourning: Bool
    let activeQuestCount: Int
    let onCreate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("QUEST KEEPER")
                    .font(.title3.weight(.black).monospaced())
                    .foregroundStyle(DungeonPalette.ink)
                Spacer(minLength: 8)
                Button(action: onCreate) {
                    Image(systemName: "plus")
                        .font(.headline.weight(.black))
                        .frame(width: 36, height: 36)
                        // Chunky square pixel button rather than a soft circle.
                        .background(DungeonPalette.hero, in: RoundedRectangle(cornerRadius: PixelStyle.corner))
                        .overlay(
                            RoundedRectangle(cornerRadius: PixelStyle.corner)
                                .stroke(DungeonPalette.ink.opacity(0.25), lineWidth: PixelStyle.border)
                        )
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("전투 추가")
            }
            HeroHeader(state: state, isMourning: isMourning, activeQuestCount: activeQuestCount)
        }
        .padding(14)
        .background(DungeonPalette.stone, in: RoundedRectangle(cornerRadius: 2))
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .stroke(DungeonPalette.ink.opacity(0.18), lineWidth: 2)  // chunky pixel border
        )
    }
}

private struct EmptyDungeonState: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            DungeonArtworkView(artwork: .battleFlag, size: 34)
            Text("오늘의 던전이 비었습니다")
                .font(.headline.weight(.bold))
                .foregroundStyle(DungeonPalette.ink)
            Text("작은 전투 하나를 추가해 시작하세요.")
                .font(.caption)
                .foregroundStyle(DungeonPalette.ink.opacity(0.7))
            Button(action: onCreate) {
                Label("전투 추가", systemImage: "plus")
            }
            .buttonStyle(.pixel)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(.horizontal, 18)
        .background(DungeonPalette.stone, in: RoundedRectangle(cornerRadius: 2))
    }
}

private struct NotificationPermissionBanner: View {
    let onOpenSettings: () -> Void

    var body: some View {
        Button(action: onOpenSettings) {
            Label {
                Text("마감 알림을 받으려면 설정에서 QuestKeeper 알림을 켜세요.")
            } icon: {
                DungeonArtworkView(artwork: .notificationsDisabled, size: 16)
            }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(DungeonPalette.danger, in: RoundedRectangle(cornerRadius: 2))
        }
    }
}
