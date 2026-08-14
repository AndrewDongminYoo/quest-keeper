import Foundation
import Testing
@testable import QuestKeeper

struct QuestCreationInputTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test("shortcut defaults details, deadline, and importance")
    func shortcutDefaults() throws {
        let input = try QuestCreationInput.shortcut(
            title: "  Defeat\nslime  ",
            details: "   ",
            deadline: nil,
            importance: nil,
            now: now
        )
        #expect(input.title == "Defeat slime")
        #expect(input.details == nil)
        #expect(input.deadline == now.addingTimeInterval(3_600))
        #expect(input.importance == .medium)
    }

    @Test("shortcut normalizes supplied details and preserves supplied values")
    func shortcutSuppliedValues() throws {
        let deadline = now.addingTimeInterval(7_200)
        let input = try QuestCreationInput.shortcut(
            title: "Quest",
            details: " First\n\n\nSecond ",
            deadline: deadline,
            importance: .high,
            now: now
        )
        #expect(input.details == "First\n\nSecond")
        #expect(input.deadline == deadline)
        #expect(input.importance == .high)
    }

    @Test("empty title and explicit non-future deadline fail before storage")
    func invalidShortcutInput() {
        #expect(throws: QuestCreationInputError.emptyTitle) {
            try QuestCreationInput.shortcut(
                title: " \n ", details: nil, deadline: nil, importance: nil, now: now
            )
        }
        #expect(throws: QuestCreationInputError.deadlineNotInFuture) {
            try QuestCreationInput.shortcut(
                title: "Quest", details: nil, deadline: now, importance: nil, now: now
            )
        }
    }
}
