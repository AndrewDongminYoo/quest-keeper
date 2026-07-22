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
                                        : "완료")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
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
            .alert("선택을 다시 확인해주세요", isPresented: $showingSaveIssue) {
                Button("확인", role: .cancel) { }
            } message: {
                Text("퀘스트 상태가 바뀌어 지금 선택을 저장하지 않았습니다.")
            }
        }
    }

    private var actionTitle: String {
        kind == .confirmation ? "오늘 이대로 시작" : "선택 완료"
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
