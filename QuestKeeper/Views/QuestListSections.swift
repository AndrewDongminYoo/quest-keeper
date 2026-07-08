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
        if !pending.isEmpty {
            Section("던전") {
                ForEach(pending) { quest in
                    QuestRow(quest: quest, now: now)
                        .listRowBackground(Color(red: 0.20, green: 0.19, blue: 0.25))
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
            Section("오늘의 무덤") {
                ForEach(dailyGraves) { quest in
                    DailyGraveRow(quest: quest) {
                        onRetryTomorrow(quest)
                    }
                    .listRowBackground(Color(red: 0.20, green: 0.19, blue: 0.25))
                }
            }
        }
    }
}
