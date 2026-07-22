import SwiftUI

struct DailyFocusSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedQuestIDs: Set<UUID>

    let quests: [Quest]
    let onSave: ([UUID]) -> Bool

    init(
        quests: [Quest],
        initialSelectedQuestIDs: [UUID],
        onSave: @escaping ([UUID]) -> Bool
    ) {
        self.quests = quests
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
                                Text(quest.deadline, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .disabled(!selectedQuestIDs.contains(quest.id) && selectedQuestIDs.count == 3)
                        .accessibilityValue(
                            selectedQuestIDs.contains(quest.id) ? "선택됨" : "선택 안 됨"
                        )
                    }
                } header: {
                    Text("오늘 집중할 퀘스트를 1–3개 선택하세요")
                } footer: {
                    Text("\(selectedQuestIDs.count)개 선택")
                }
            }
            .navigationTitle("핵심 퀘스트 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("선택 완료 (\(selectedQuestIDs.count)/3)") {
                        let orderedIDs = quests.map(\.id).filter(selectedQuestIDs.contains)
                        _ = onSave(orderedIDs)
                        dismiss()
                    }
                    .disabled(!DailyFocusState.isValidSelection(Array(selectedQuestIDs)))
                }
            }
        }
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
