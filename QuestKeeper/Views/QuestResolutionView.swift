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
                Section(AppStrings.questResolutionSection) {
                    Text(quest.title)
                    LabeledContent(AppStrings.questResolutionStatusLabel, value: statusText)
                    LabeledContent(
                        AppStrings.questFieldDeadline,
                        value: quest.deadline.formatted(date: .abbreviated, time: .shortened)
                    )
                }
                if quest.snapshot.isVisibleDailyGrave(at: now), let onRetryTomorrow {
                    Section {
                        Button {
                            onRetryTomorrow()
                            dismiss()
                        } label: {
                            Label(AppStrings.questActionRetryTomorrow, systemImage: "arrow.uturn.forward")
                        }
                    }
                }
            }
            .navigationTitle(AppStrings.questResolutionNavigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppStrings.commonActionClose) { dismiss() }
                }
            }
        }
    }

    private var statusText: String {
        let resource: LocalizedStringResource = switch quest.snapshot.outcome(at: now) {
        case .pending:
            AppStrings.questResolutionStatusPending
        case .victory:
            AppStrings.questStatusCompleted
        case .grave:
            AppStrings.questResolutionStatusGrave
        }
        return AppStrings.resolve(resource, locale: .current)
    }
}
