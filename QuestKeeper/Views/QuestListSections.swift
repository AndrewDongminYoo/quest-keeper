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
    let now: Date
    let onComplete: (Quest) -> Void
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
                        DailyGraveRow(quest: quest) {
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
    }
}

private struct SwipeableQuestRow: View {
    let quest: Quest
    let now: Date
    let onComplete: (Quest) -> Void
    let onDelete: (Quest) -> Void
    let onEdit: (Quest) -> Void

    @State private var offset: CGFloat = 0

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                actionButton(title: "완료", systemImage: "checkmark", color: Color(red: 0.18, green: 0.54, blue: 0.29)) {
                    reset()
                    onComplete(quest)
                }
                Spacer(minLength: 0)
                actionButton(title: "삭제", systemImage: "trash", color: Color(red: 0.70, green: 0.18, blue: 0.16)) {
                    reset()
                    onDelete(quest)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))

            QuestRow(quest: quest, now: now)
                .offset(x: offset)
                .contentShape(Rectangle())
                .onTapGesture {
                    if offset == 0 {
                        onEdit(quest)
                    } else {
                        reset()
                    }
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .gesture(
            DragGesture(minimumDistance: 18)
                .onChanged { value in
                    guard isHorizontalSwipe(value.translation) else { return }
                    offset = SwipeRevealState.offset(for: value.translation.width)
                }
                .onEnded { value in
                    guard isHorizontalSwipe(value.translation) else {
                        reset()
                        return
                    }

                    if let side = SwipeRevealState.revealedSide(for: value.translation.width) {
                        withAnimation(.snappy(duration: 0.18)) {
                            offset = SwipeRevealState.restingOffset(for: side)
                        }
                    } else {
                        reset()
                    }
                }
        )
        .accessibilityAction(named: "완료") { onComplete(quest) }
        .accessibilityAction(named: "삭제") { onDelete(quest) }
    }

    private func actionButton(title: String, systemImage: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: SwipeRevealState.maxOffset)
                .frame(minHeight: 92)
                .background(color)
        }
        .buttonStyle(.plain)
    }

    private func isHorizontalSwipe(_ translation: CGSize) -> Bool {
        abs(translation.width) > abs(translation.height)
    }

    private func reset() {
        withAnimation(.snappy(duration: 0.18)) {
            offset = 0
        }
    }
}
