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

    @State private var title: String
    @State private var deadline: Date
    @State private var importance: Importance
    @State private var showingChunkingGuide = false

    init(
        quest: Quest?,
        notificationService: QuestNotificationService = .shared,
        onAuthorizationChange: @escaping (QuestNotificationAuthorization) -> Void = { _ in }
    ) {
        self.quest = quest
        self.notificationService = notificationService
        self.onAuthorizationChange = onAuthorizationChange
        _title = State(initialValue: quest?.title ?? "")
        let fallbackDeadline = Date().addingTimeInterval(60 * 60)
        _deadline = State(initialValue: max(quest?.deadline ?? fallbackDeadline, Date.now))
        _importance = State(initialValue: quest?.importance ?? .medium)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("제목", text: $title)
                DatePicker("마감", selection: $deadline, in: Date.now...)
                Picker("중요도", selection: $importance) {
                    Text("낮음").tag(Importance.low)
                    Text("보통").tag(Importance.medium)
                    Text("높음").tag(Importance.high)
                }
            }
            .navigationTitle(quest == nil ? "새 퀘스트" : "퀘스트 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { attemptSave() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("너무 큰 퀘스트예요", isPresented: $showingChunkingGuide) {
                Button("작게 쪼개기", role: .cancel) { }
                Button("그래도 진행") {
                    save()
                }
            } message: {
                Text("작게 쪼개면 몹도 작아져요.")
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
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        let savedQuest: Quest
        if let quest {
            quest.title = trimmed
            quest.deadline = deadline
            quest.importance = importance
            savedQuest = quest
        } else {
            let newQuest = Quest(title: trimmed, deadline: deadline, importance: importance)
            modelContext.insert(newQuest)
            savedQuest = newQuest
        }
        dismiss()

        Task { @MainActor in
            let authorization = await notificationService.sync(quest: savedQuest, now: .now)
            onAuthorizationChange(authorization)
        }
    }
}
