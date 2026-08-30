import SwiftUI

struct RoutineEditor: View {
    @Environment(\.dismiss) private var dismiss

    let routine: RoutineRule?
    let onSave: (RoutineRule?, String) -> Bool

    @State private var title: String

    init(routine: RoutineRule?, onSave: @escaping (RoutineRule?, String) -> Bool) {
        self.routine = routine
        self.onSave = onSave
        _title = State(initialValue: QuestTitlePolicy.constrainedInput(routine?.title ?? ""))
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(AppStrings.routineEditorTitleField, text: Binding(
                    get: { title },
                    set: { title = QuestTitlePolicy.constrainedInput($0) }
                ))
                .accessibilityIdentifier("routineEditorTitleField")
            }
            .navigationTitle(routine == nil ? AppStrings.routineEditorNewTitle : AppStrings.routineEditorEditTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppStrings.commonActionCancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppStrings.questEditorSaveAction) {
                        if onSave(routine, title) {
                            dismiss()
                        }
                    }
                    .disabled(QuestTitlePolicy.normalized(title).isEmpty)
                    .accessibilityIdentifier("routineEditorSaveButton")
                }
            }
        }
    }
}
