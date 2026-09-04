//
//  QuestDetailView.swift
//  QuestKeeper
//
//  Common detail surface for a quest's current derived state.
//

import SwiftUI

nonisolated struct QuestDetailCapabilities: Equatable, Sendable {
    static let readOnly = QuestDetailCapabilities(
        canEdit: false,
        canRetryTomorrow: false,
        canRecordLateCompletion: false
    )

    let canEdit: Bool
    let canRetryTomorrow: Bool
    /// Whether the sheet offers "완료로 기록하기" — the user actually finished this after the deadline.
    let canRecordLateCompletion: Bool

    static func make(snapshot: QuestSnapshot, now: Date) -> QuestDetailCapabilities {
        switch snapshot.outcome(at: now) {
        case .pending:
            QuestDetailCapabilities(
                canEdit: true,
                canRetryTomorrow: false,
                canRecordLateCompletion: false
            )
        // Both recovery choices withdraw once a completion is recorded. `QuestActions.retryTomorrow`
        // clears `completedAt`, so leaving retry here would silently discard the fact the user just
        // recorded — see docs/specs/024-late-completion.md.
        case .grave where snapshot.isVisibleDailyGrave(at: now) && !snapshot.isCompleted:
            QuestDetailCapabilities(
                canEdit: false,
                canRetryTomorrow: true,
                canRecordLateCompletion: true
            )
        case .victory, .grave:
            .readOnly
        }
    }
}

struct QuestDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let quest: Quest
    let now: Date
    let notificationService: QuestNotificationService
    let onAuthorizationChange: (QuestNotificationAuthorization) -> Void
    let onSaved: (Quest) -> Bool
    let onEditingChange: (Bool) -> Void
    let onRetryTomorrow: (() -> Void)?
    let onRecordLateCompletion: (() -> Void)?

    @State private var isEditing = false

    init(
        quest: Quest,
        now: Date,
        notificationService: QuestNotificationService = .shared,
        onAuthorizationChange: @escaping (QuestNotificationAuthorization) -> Void = { _ in },
        onSaved: @escaping (Quest) -> Bool = { _ in true },
        onEditingChange: @escaping (Bool) -> Void = { _ in },
        onRetryTomorrow: (() -> Void)? = nil,
        onRecordLateCompletion: (() -> Void)? = nil
    ) {
        self.quest = quest
        self.now = now
        self.notificationService = notificationService
        self.onAuthorizationChange = onAuthorizationChange
        self.onSaved = onSaved
        self.onEditingChange = onEditingChange
        self.onRetryTomorrow = onRetryTomorrow
        self.onRecordLateCompletion = onRecordLateCompletion
    }

    private var capabilities: QuestDetailCapabilities {
        .make(snapshot: quest.snapshot, now: now)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(AppStrings.questResolutionSection) {
                    Text(quest.title)
                    LabeledContent(AppStrings.questResolutionStatusLabel, value: statusText)
                    if let details = quest.details {
                        LabeledContent(AppStrings.questFieldDetails) {
                            Text(details)
                                .accessibilityIdentifier("questDetailDetails")
                        }
                    }
                    LabeledContent(
                        AppStrings.questFieldDeadline,
                        value: quest.deadline.formatted(date: .abbreviated, time: .shortened)
                    )
                    LabeledContent(AppStrings.questEditorImportanceField) {
                        Text(importanceText)
                    }
                    if let completedAt = quest.completedAt {
                        LabeledContent(
                            AppStrings.questFieldCompletedAt,
                            value: completedAt.formatted(date: .abbreviated, time: .shortened)
                        )
                    }
                }
                if capabilities.canRetryTomorrow || capabilities.canRecordLateCompletion {
                    Section {
                        // Ordered so the already-done case is read first: someone who finished the
                        // work should not have to walk past an offer to redo it.
                        if capabilities.canRecordLateCompletion, let onRecordLateCompletion {
                            Button {
                                onRecordLateCompletion()
                                dismiss()
                            } label: {
                                Label(
                                    AppStrings.questActionRecordLateCompletion,
                                    systemImage: "checkmark.circle"
                                )
                            }
                            .accessibilityIdentifier("questDetailRecordLateCompletionButton")
                        }
                        if capabilities.canRetryTomorrow, let onRetryTomorrow {
                            Button {
                                onRetryTomorrow()
                                dismiss()
                            } label: {
                                Label(AppStrings.questActionRetryTomorrow, systemImage: "arrow.uturn.forward")
                            }
                            .accessibilityIdentifier("questDetailRetryButton")
                        }
                    }
                }
            }
            .navigationTitle(AppStrings.questResolutionNavigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppStrings.commonActionClose) { dismiss() }
                }
                if capabilities.canEdit {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(AppStrings.questActionEdit) {
                            isEditing = true
                            onEditingChange(true)
                        }
                            .accessibilityIdentifier("questDetailEditButton")
                    }
                }
            }
            .sheet(isPresented: $isEditing, onDismiss: { onEditingChange(false) }) {
                QuestEditor(
                    quest: quest,
                    notificationService: notificationService,
                    onAuthorizationChange: onAuthorizationChange,
                    onSaved: onSaved
                )
            }
        }
    }

    private var importanceText: LocalizedStringResource {
        switch quest.importance {
        case .low:
            AppStrings.questEditorImportanceLow
        case .medium:
            AppStrings.questEditorImportanceMedium
        case .high:
            AppStrings.questEditorImportanceHigh
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
