//
//  QuestListSections.swift
//  QuestKeeper
//
//  Phase 2 — Active + daily grave sections. Membership is DERIVED (spec 003 §3): it is passed in
//  already partitioned at the timeline's `now`, never fetched from @Query (outcome depends on `now`).
//

import SwiftUI

struct QuestListSections: View {
    let heroAppearance: HeroAppearance
    let allQuests: [Quest]
    let pending: [Quest]
    let dailyGraves: [Quest]
    let newlyMissedQuestIDs: Set<UUID>
    let guidedCompletionQuestID: UUID?
    let dailyFocusQuestIDs: [UUID]?
    let completedDailyFocusQuestIDs: Set<UUID>
    let onEditDailyFocus: () -> Void
    let now: Date
    let onComplete: (Quest, Date) -> Void
    let onRetryTomorrow: (Quest) -> Void
    let onDelete: (Quest) -> Void
    let onEdit: (Quest) -> Void

    @State private var showsRemainingQuests = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let dailyFocusQuestIDs {
                dailyFocusSections(questIDs: dailyFocusQuestIDs)
            } else {
                standardPendingSection
            }

            if !dailyGraves.isEmpty {
                BoardSectionTitle(
                    title: AppStrings.resolve(AppStrings.dungeonGraveSectionTitle, locale: .current),
                    count: dailyGraves.count
                )
                VStack(spacing: 10) {
                    ForEach(dailyGraves) { quest in
                        DailyGraveRow(quest: quest, isNewlyMissed: newlyMissedQuestIDs.contains(quest.id)) {
                            onRetryTomorrow(quest)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var standardPendingSection: some View {
        if !pending.isEmpty {
            BoardSectionTitle(title: AppStrings.resolve(AppStrings.dungeonSectionTitle, locale: .current), count: pending.count)
            questRows(pending)
        }
    }

    private func dailyFocusSections(questIDs: [UUID]) -> some View {
        let questsByID = Dictionary(uniqueKeysWithValues: allQuests.map { ($0.id, $0) })
        let focusQuests = questIDs.compactMap { questsByID[$0] }
        let remainingQuests = pending.filter { !Set(questIDs).contains($0.id) }

        return VStack(alignment: .leading, spacing: 12) {
            BoardSectionTitle(title: AppStrings.resolve(AppStrings.focusSectionTitle, locale: .current), count: focusQuests.count)
            HStack {
                Text(AppStrings.focusProgress(completedDailyFocusQuestIDs.count, focusQuests.count))
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(DungeonPalette.ink.opacity(0.72))
                Spacer()
                Button(AppStrings.focusActionEdit, action: onEditDailyFocus)
                    .font(.caption.weight(.bold))
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }

            if focusQuests.isEmpty {
                Text(AppStrings.focusEmptyBody)
                    .font(.subheadline)
                    .foregroundStyle(DungeonPalette.ink.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 10) {
                    ForEach(focusQuests) { quest in
                        if completedDailyFocusQuestIDs.contains(quest.id) {
                            QuestRow(quest: quest, now: now, heroAppearance: heroAppearance, isCompleted: true)
                        } else {
                            swipeableRow(quest)
                        }
                    }
                }
            }

            if !remainingQuests.isEmpty {
                DisclosureGroup(isExpanded: $showsRemainingQuests) {
                    questRows(remainingQuests)
                        .padding(.top, 10)
                } label: {
                    Text(AppStrings.questRemainingCount(remainingQuests.count))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DungeonPalette.ink.opacity(0.82))
                }
            }
        }
    }

    private func questRows(_ quests: [Quest]) -> some View {
        VStack(spacing: 10) {
            ForEach(quests) { quest in
                swipeableRow(quest)
            }
        }
    }

    private func swipeableRow(_ quest: Quest) -> some View {
        SwipeableQuestRow(
            quest: quest,
            now: now,
            heroAppearance: heroAppearance,
            showsGuidedCompletion: quest.id == guidedCompletionQuestID,
            onComplete: onComplete,
            onDelete: onDelete,
            onEdit: onEdit
        )
    }
}

private struct BoardSectionTitle: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(.caption, design: .monospaced).weight(.black))
                .foregroundStyle(DungeonPalette.ink.opacity(0.82))
            Text(verbatim: "\(count)")
                .font(.caption2.monospacedDigit().weight(.bold))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(DungeonPalette.ink.opacity(0.12), in: RoundedRectangle(cornerRadius: 2))
                .foregroundStyle(DungeonPalette.ink.opacity(0.72))
            Spacer()
        }
        .textCase(.uppercase)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct SwipeableQuestRow: View {
    let quest: Quest
    let now: Date
    let heroAppearance: HeroAppearance
    let showsGuidedCompletion: Bool
    let onComplete: (Quest, Date) -> Void
    let onDelete: (Quest) -> Void
    let onEdit: (Quest) -> Void

    @State private var offset: CGFloat = 0
    @State private var isTrackingSwipe = false
    @State private var battlePhase: QuestBattlePhase = .idle
    @State private var isResolvingBattle = false
    @State private var battleTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                actionButton(
                    title: AppStrings.resolve(AppStrings.questActionComplete, locale: .current),
                    artwork: .complete,
                    color: DungeonPalette.hero
                ) {
                    completeWithBattle()
                }
                Spacer(minLength: 0)
                actionButton(
                    title: AppStrings.resolve(AppStrings.questActionDelete, locale: .current),
                    artwork: .delete,
                    color: DungeonPalette.danger
                ) {
                    guard !isResolvingBattle else { return }
                    reset()
                    onDelete(quest)
                }
            }
            .frame(maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .disabled(isResolvingBattle)
            .accessibilityHidden(isResolvingBattle)

            QuestRow(
                quest: quest,
                now: now,
                heroAppearance: heroAppearance,
                battlePhase: battlePhase,
                guidanceText: showsGuidedCompletion
                    ? AppStrings.resolve(AppStrings.dungeonFirstWinGuidance, locale: .current)
                    : nil
            )
                .contentShape(Rectangle())
                .offset(x: offset)
                .onTapGesture {
                    guard !isResolvingBattle else { return }
                    if offset == 0 {
                        onEdit(quest)
                    } else {
                        reset()
                    }
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .simultaneousGesture(
            DragGesture(minimumDistance: 18)
                .onChanged { value in
                    guard !isResolvingBattle else { return }
                    guard shouldTrackSwipe(value.translation) else { return }
                    isTrackingSwipe = true
                    offset = SwipeRevealState.offset(for: value.translation.width)
                }
                .onEnded { value in
                    guard !isResolvingBattle else { return }
                    guard isTrackingSwipe else { return }
                    isTrackingSwipe = false

                    if let side = SwipeRevealState.revealedSide(for: value.translation.width) {
                        withAnimation(.snappy(duration: 0.18)) {
                            offset = SwipeRevealState.restingOffset(for: side)
                        }
                    } else {
                        reset()
                    }
                }
        )
        .accessibilityValue(QuestBattleResolution.accessibilityValue(for: battlePhase))
        .accessibilityActions {
            if !isResolvingBattle {
                Button(AppStrings.questActionComplete) { completeWithBattle() }
                Button(AppStrings.questActionDelete) { onDelete(quest) }
            }
        }
        .onChange(of: quest.id) { _, _ in
            battleTask?.cancel()
            battleTask = nil
            battlePhase = .idle
            isResolvingBattle = false
            isTrackingSwipe = false
            offset = 0
        }
        .onDisappear {
            // 지연 스택에서 행이 화면 밖으로 스크롤될 때도 호출되므로,
            // 이미 접수된 완료 처리는 취소하지 않고 그대로 커밋되게 둔다.
            guard !isResolvingBattle else { return }
            battleTask?.cancel()
            battleTask = nil
            battlePhase = .idle
            isTrackingSwipe = false
            offset = 0
        }
    }

    private func actionButton(title: String, artwork: DungeonArtwork, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label {
                Text(title)
            } icon: {
                DungeonArtworkView(artwork: artwork, size: 14)
            }
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: SwipeRevealState.maxOffset)
                .frame(maxHeight: .infinity)
                .background(color)
        }
        .buttonStyle(.plain)
    }

    private func completeWithBattle() {
        guard let completedAt = QuestBattleResolution.acceptedTimestamp(isResolving: isResolvingBattle, now: .now) else { return }
        isResolvingBattle = true
        battleTask?.cancel()
        withAnimation(.snappy(duration: 0.18)) {
            offset = 0
            battlePhase = .windUp
        }

        battleTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(QuestBattleResolution.strikingPhaseDelay))
            guard !Task.isCancelled else { return }
            withAnimation(.snappy(duration: 0.16)) {
                battlePhase = .striking
            }

            let defeatedDelay = QuestBattleResolution.defeatedPhaseDelay - QuestBattleResolution.strikingPhaseDelay
            try? await Task.sleep(for: .seconds(defeatedDelay))
            guard !Task.isCancelled else { return }
            withAnimation(.snappy(duration: 0.2)) {
                battlePhase = .defeated
            }

            let remainingDelay = QuestBattleResolution.commitDelay - QuestBattleResolution.defeatedPhaseDelay
            try? await Task.sleep(for: .seconds(remainingDelay))
            guard !Task.isCancelled else { return }
            onComplete(quest, completedAt)
        }
    }

    private func shouldTrackSwipe(_ translation: CGSize) -> Bool {
        SwipeRevealState.shouldTrackDrag(width: translation.width, height: translation.height, isTracking: isTrackingSwipe)
    }

    private func reset() {
        withAnimation(.snappy(duration: 0.18)) {
            offset = 0
        }
    }
}
