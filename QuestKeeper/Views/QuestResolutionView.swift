//
//  QuestResolutionView.swift
//  QuestKeeper
//
//  Phase 3 — read-only destination for notification taps on resolved quests.
//

import SwiftUI

struct QuestResolutionView: View {
    @Environment(\.dismiss) private var dismiss

    let quest: Quest
    let now: Date
    let onRetryTomorrow: (() -> Void)?

    init(quest: Quest, now: Date, onRetryTomorrow: (() -> Void)? = nil) {
        self.quest = quest
        self.now = now
        self.onRetryTomorrow = onRetryTomorrow
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("퀘스트") {
                    Text(quest.title)
                    LabeledContent("상태", value: statusText)
                    LabeledContent("마감", value: quest.deadline.formatted(date: .abbreviated, time: .shortened))
                }
                if quest.snapshot.isVisibleDailyGrave(at: now), let onRetryTomorrow {
                    Section {
                        Button {
                            onRetryTomorrow()
                            dismiss()
                        } label: {
                            Label("내일 도전하기", systemImage: "arrow.uturn.forward")
                        }
                    }
                }
            }
            .navigationTitle("퀘스트 기록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    private var statusText: String {
        switch quest.snapshot.outcome(at: now) {
        case .pending:
            "진행 중"
        case .victory:
            "완료"
        case .grave:
            "무덤"
        }
    }
}
