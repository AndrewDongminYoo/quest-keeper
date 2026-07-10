//
//  QuestListSections.swift
//  QuestKeeper
//
//  Phase 2 — Active + daily grave sections. Membership is DERIVED (spec 003 §3): it is passed in
//  already partitioned at the timeline's `now`, never fetched from @Query (outcome depends on `now`).
//

import SwiftUI

struct QuestListSections: View {
    let pending: [Quest]
    let dailyGraves: [Quest]
    let newlyMissedQuestIDs: Set<UUID>
    let now: Date
    let onComplete: (Quest, Date) -> Void
    let onRetryTomorrow: (Quest) -> Void
    let onDelete: (Quest) -> Void
    let onEdit: (Quest) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !pending.isEmpty {
                BoardSectionTitle(title: "던전", count: pending.count)
                VStack(spacing: 10) {
                    ForEach(pending) { quest in
                        SwipeableQuestRow(
                            quest: quest,
                            now: now,
                            onComplete: onComplete,
                            onDelete: onDelete,
                            onEdit: onEdit
                        )
                    }
                }
            }

            if !dailyGraves.isEmpty {
                BoardSectionTitle(title: "오늘의 무덤", count: dailyGraves.count)
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
}

private struct BoardSectionTitle: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(.caption, design: .monospaced).weight(.black))
                .foregroundStyle(.white.opacity(0.82))
            Text("\(count)")
                .font(.caption2.monospacedDigit().weight(.bold))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.12), in: Capsule())
                .foregroundStyle(.white.opacity(0.72))
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
                actionButton(title: "완료", systemImage: "checkmark", color: Color(red: 0.18, green: 0.54, blue: 0.29)) {
                    completeWithBattle()
                }
                Spacer(minLength: 0)
                actionButton(title: "삭제", systemImage: "trash", color: Color(red: 0.70, green: 0.18, blue: 0.16)) {
                    guard !isResolvingBattle else { return }
                    reset()
                    onDelete(quest)
                }
            }
            .frame(maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            QuestRow(quest: quest, now: now, battlePhase: battlePhase)
                .offset(x: offset)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !isResolvingBattle else { return }
                    if offset == 0 {
                        onEdit(quest)
                    } else {
                        reset()
                    }
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
        .accessibilityAction(named: "완료") { completeWithBattle() }
        .accessibilityValue(isResolvingBattle ? "완료 처리 중" : "")
        .accessibilityAction(named: "삭제") {
            guard !isResolvingBattle else { return }
            onDelete(quest)
        }
        .onChange(of: quest.id) { _, _ in
            battleTask?.cancel()
            battleTask = nil
            battlePhase = .idle
            isResolvingBattle = false
            isTrackingSwipe = false
            offset = 0
        }
    }

    private func actionButton(title: String, systemImage: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: SwipeRevealState.maxOffset)
                .frame(maxHeight: .infinity)
                .background(color)
        }
        .buttonStyle(.plain)
    }

    private func completeWithBattle() {
        guard QuestBattleResolution.shouldAcceptCompletion(isResolving: isResolvingBattle) else { return }

        let completedAt = Date.now
        isResolvingBattle = true
        battleTask?.cancel()
        withAnimation(.snappy(duration: 0.18)) {
            offset = 0
            battlePhase = .striking
        }

        battleTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(QuestBattleResolution.defeatedPhaseDelay))
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
