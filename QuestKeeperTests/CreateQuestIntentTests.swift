import Foundation
import Testing
@testable import QuestKeeper

struct CreateQuestIntentTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test("intent parameters adapt in title details deadline importance order")
    func adaptsParameters() throws {
        let deadline = now.addingTimeInterval(7_200)
        let input = try CreateQuestIntent.creationInput(
            title: "  Shortcut quest  ",
            details: " First\n\n\nSecond ",
            deadline: deadline,
            importance: .high,
            now: now
        )

        #expect(input.title == "Shortcut quest")
        #expect(input.details == "First\n\nSecond")
        #expect(input.deadline == deadline)
        #expect(input.importance == .high)
    }

    @Test("omitted optional parameters use the approved defaults")
    func adaptsDefaults() throws {
        let input = try CreateQuestIntent.creationInput(
            title: "Shortcut quest",
            details: nil,
            deadline: nil,
            importance: nil,
            now: now
        )

        #expect(input.details == nil)
        #expect(input.deadline == now.addingTimeInterval(3_600))
        #expect(input.importance == .medium)
    }

    @Test("dialog classification distinguishes permission and technical follow-up failures")
    func classifiesDialogs() {
        #expect(CreateQuestIntentDialogKind.make(
            authorization: .allowed,
            followUpFailures: []
        ) == .created)
        #expect(CreateQuestIntentDialogKind.make(
            authorization: .denied,
            followUpFailures: []
        ) == .createdNeedsNotificationPermission)
        #expect(CreateQuestIntentDialogKind.make(
            authorization: .unavailable,
            followUpFailures: [.notifications]
        ) == .createdWithFollowUpWarning)
        #expect(CreateQuestIntentDialogKind.make(
            authorization: .denied,
            followUpFailures: [.widgetSnapshot]
        ) == .createdWithFollowUpWarningAndNotificationPermission)
    }
}
