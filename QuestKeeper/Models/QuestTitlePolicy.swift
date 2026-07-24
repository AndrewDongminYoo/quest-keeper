import Foundation

nonisolated enum QuestTitlePolicy {
    static let maximumLength = 120

    static func constrainedInput(_ title: String) -> String {
        String(title.prefix(maximumLength))
    }

    static func normalized(_ title: String) -> String {
        constrainedInput(title.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
