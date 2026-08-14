import Foundation

nonisolated enum QuestCreationInputError: Error, Equatable, Sendable {
    case emptyTitle
    case deadlineNotInFuture
}

nonisolated struct QuestCreationInput: Equatable, Sendable {
    static let defaultDeadlineOffset: TimeInterval = 60 * 60

    let title: String
    let details: String?
    let deadline: Date
    let importance: Importance

    init(title: String, details: String?, deadline: Date, importance: Importance) throws {
        let normalizedTitle = QuestTitlePolicy.normalized(title)
        guard !normalizedTitle.isEmpty else { throw QuestCreationInputError.emptyTitle }
        self.title = normalizedTitle
        self.details = QuestDetailsPolicy.normalized(details)
        self.deadline = deadline
        self.importance = importance
    }

    static func shortcut(
        title: String,
        details: String?,
        deadline: Date?,
        importance: Importance?,
        now: Date
    ) throws -> QuestCreationInput {
        let resolvedDeadline = deadline ?? now.addingTimeInterval(defaultDeadlineOffset)
        if deadline != nil, resolvedDeadline <= now {
            throw QuestCreationInputError.deadlineNotInFuture
        }
        return try QuestCreationInput(
            title: title,
            details: details,
            deadline: resolvedDeadline,
            importance: importance ?? .medium
        )
    }
}
