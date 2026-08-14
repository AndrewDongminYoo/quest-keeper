//
//  QuestEditor.swift
//  QuestKeeper
//
//  Phase 2 — create / edit form. Create inserts a new Quest; edit mutates a pending one in place.
//

import SwiftUI
import SwiftData

struct QuestEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// `nil` = create a new quest; non-nil = edit this existing one.
    let quest: Quest?
    let notificationService: QuestNotificationService
    let onAuthorizationChange: (QuestNotificationAuthorization) -> Void
    let onSaved: (Quest) -> Void

    @State private var title: String
    @State private var details: String
    @State private var deadline: Date
    @State private var importance: Importance
    @State private var showingChunkingGuide = false

    init(
        quest: Quest?,
        draft: QuestEditorDraft? = nil,
        notificationService: QuestNotificationService = .shared,
        onAuthorizationChange: @escaping (QuestNotificationAuthorization) -> Void = { _ in },
        onSaved: @escaping (Quest) -> Void = { _ in }
    ) {
        self.quest = quest
        self.notificationService = notificationService
        self.onAuthorizationChange = onAuthorizationChange
        self.onSaved = onSaved
        let now = Date.now
        let initialTitle = QuestTitlePolicy.constrainedInput(quest?.title ?? draft?.title ?? "")
        let initialDeadline = quest?.deadline ?? draft?.deadline ?? now.addingTimeInterval(60 * 60)
        let initialImportance = quest?.importance ?? draft?.importance ?? .medium
        _title = State(initialValue: initialTitle)
        _details = State(initialValue: QuestDetailsPolicy.constrainedInput(quest?.details ?? ""))
        _deadline = State(initialValue: max(initialDeadline, now))
        _importance = State(initialValue: initialImportance)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(AppStrings.questEditorTitleField, text: Binding(
                    get: { title },
                    set: { title = QuestTitlePolicy.constrainedInput($0) }
                ))
                TextField(
                    AppStrings.questFieldDetails,
                    text: Binding(
                        get: { details },
                        set: { details = QuestDetailsPolicy.constrainedInput($0) }
                    ),
                    axis: .vertical
                )
                .lineLimit(3...8)
                .accessibilityIdentifier("questDetailsField")
                DatePicker(AppStrings.questFieldDeadline, selection: $deadline, in: Date.now...)
                Picker(AppStrings.questEditorImportanceField, selection: $importance) {
                    Text(AppStrings.questEditorImportanceLow).tag(Importance.low)
                    Text(AppStrings.questEditorImportanceMedium).tag(Importance.medium)
                    Text(AppStrings.questEditorImportanceHigh).tag(Importance.high)
                }
            }
            .navigationTitle(quest == nil ? AppStrings.questEditorNewTitle : AppStrings.questEditorEditTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppStrings.commonActionCancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppStrings.questEditorSaveAction) { attemptSave() }
                        .disabled(QuestTitlePolicy.normalized(title).isEmpty)
                        .accessibilityIdentifier("questEditorSaveButton")
                }
            }
            .alert(AppStrings.questEditorTooLarge, isPresented: $showingChunkingGuide) {
                Button(AppStrings.questEditorChunkingGuideConfirm, role: .cancel) { }
                Button(AppStrings.questEditorChunkingGuideProceedAnyway) {
                    save()
                }
            } message: {
                Text(AppStrings.questEditorChunkingGuideMessage)
            }
        }
    }

    private func attemptSave() {
        if QuestActions.needsChunkingGuide(deadline: deadline, now: .now) {
            showingChunkingGuide = true
            return
        }
        save()
    }

    private func save() {
        let savedAt = Date.now
        guard let input = try? QuestCreationInput(
            title: title,
            details: details,
            deadline: deadline,
            importance: importance
        ) else { return }
        let savedQuest: Quest
        if let quest {
            quest.title = input.title
            quest.details = input.details
            quest.deadline = input.deadline
            quest.importance = input.importance
            savedQuest = quest
        } else {
            let newQuest = Quest(
                title: input.title,
                deadline: input.deadline,
                importance: input.importance,
                details: input.details
            )
            modelContext.insert(newQuest)
            _ = RetentionEventRecorder.recordQuestCreated(
                questID: newQuest.id,
                at: savedAt,
                in: modelContext
            )
            savedQuest = newQuest
        }
        onSaved(savedQuest)
        dismiss()

        Task { @MainActor in
            let authorization = await notificationService.sync(quest: savedQuest, now: .now)
            onAuthorizationChange(authorization)
        }
    }
}
