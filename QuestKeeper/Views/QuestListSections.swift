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
                        QuestRow(quest: quest, now: now)
                            .contentShape(Rectangle())
                            .onTapGesture { onEdit(quest) }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button { onComplete(quest) } label: {
                                    Label("완료", systemImage: "checkmark")
                                }
                                .tint(.green)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { onDelete(quest) } label: {
                                    Label("삭제", systemImage: "trash")
                                }
                            }
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
