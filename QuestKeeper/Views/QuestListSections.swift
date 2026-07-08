//
//  QuestListSections.swift
//  QuestKeeper
//
//  Phase 2 — Active + Graveyard sections. Membership is DERIVED (spec 003 §3): it is passed in
//  already partitioned at the timeline's `now`, never fetched from @Query (outcome depends on `now`).
//

import SwiftUI

struct QuestListSections: View {
    let pending: [Quest]
    let graves: [Quest]
    let now: Date
    let onComplete: (Quest) -> Void
    let onDelete: (Quest) -> Void
    let onEdit: (Quest) -> Void

    var body: some View {
        if !pending.isEmpty {
            Section("진행 중") {
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

        if !graves.isEmpty {
            // No swipe actions here: a grave is permanent and undeletable.
            Section("무덤") {
                ForEach(graves) { quest in
                    GraveRow(quest: quest)
                }
            }
        }
    }
}
