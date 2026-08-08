import SwiftUI

struct DailyFocusSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedQuestIDs: Set<UUID>
    @State private var showingSaveIssue = false

    let quests: [Quest]
    let kind: DailyFocusSelectionKind
    let onSave: ([UUID]) -> Bool

    init(
        quests: [Quest],
        initialSelectedQuestIDs: [UUID],
        kind: DailyFocusSelectionKind,
        onSave: @escaping ([UUID]) -> Bool
    ) {
        self.quests = quests
        self.kind = kind
        self.onSave = onSave
        _selectedQuestIDs = State(initialValue: Set(initialSelectedQuestIDs))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(quests) { quest in
                        Toggle(isOn: binding(for: quest.id)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(quest.title)
                                TimelineView(.periodic(from: .now, by: 60)) { context in
                                    Text(quest.completedAt == nil
                                        ? DungeonPresentation.countdownText(
                                            deadline: quest.deadline,
                                            now: context.date
                                        )
                                        : AppStrings.resolve(AppStrings.questStatusCompleted, locale: .current))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .disabled(!selectedQuestIDs.contains(quest.id) && selectedQuestIDs.count == 3)
                        .accessibilityValue(
                            AppStrings.resolve(
                                selectedQuestIDs.contains(quest.id)
                                    ? AppStrings.dailyFocusSelectionSelectedValue
                                    : AppStrings.dailyFocusSelectionNotSelectedValue,
                                locale: .current
                            )
                        )
                    }
                } header: {
                    Text(AppStrings.dailyFocusSelectionHeader)
                } footer: {
                    Text(AppStrings.dailyFocusSelectionFooterCount(selectedQuestIDs.count))
                }
            }
            .navigationTitle(AppStrings.focusActionEdit)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppStrings.commonActionCancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("\(actionTitle) (\(selectedQuestIDs.count)/3)") {
                        let orderedIDs = quests.map(\.id).filter(selectedQuestIDs.contains)
                        if onSave(orderedIDs) {
                            dismiss()
                        } else {
                            showingSaveIssue = true
                        }
                    }
                    .disabled(!DailyFocusState.isValidSelection(Array(selectedQuestIDs)))
                }
            }
            .alert(AppStrings.selectionReissueAlertTitle, isPresented: $showingSaveIssue) {
                Button(AppStrings.selectionReissueAlertConfirmAction, role: .cancel) { }
            } message: {
                Text(AppStrings.selectionReissueAlertMessage)
            }
        }
    }

    private var actionTitle: String {
        AppStrings.resolve(
            kind == .confirmation ? AppStrings.focusActionConfirm : AppStrings.dailyFocusSelectionCompleteAction,
            locale: .current
        )
    }

    private func binding(for questID: UUID) -> Binding<Bool> {
        Binding(
            get: { selectedQuestIDs.contains(questID) },
            set: { isSelected in
                if isSelected {
                    guard selectedQuestIDs.count < 3 else { return }
                    selectedQuestIDs.insert(questID)
                } else {
                    selectedQuestIDs.remove(questID)
                }
            }
        )
    }
}
