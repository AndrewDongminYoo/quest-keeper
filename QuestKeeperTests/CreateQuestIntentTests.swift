import AppIntents
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
            importance: "high",
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

    @Test("raw importance values map to quest importance and omitted values default to medium")
    func adaptsRawImportanceValues() throws {
        let low = try CreateQuestIntent.creationInput(
            title: "Low priority shortcut quest",
            details: nil,
            deadline: nil,
            importance: "low",
            now: now
        )
        let medium = try CreateQuestIntent.creationInput(
            title: "Medium priority shortcut quest",
            details: nil,
            deadline: nil,
            importance: "medium",
            now: now
        )
        let high = try CreateQuestIntent.creationInput(
            title: "High priority shortcut quest",
            details: nil,
            deadline: nil,
            importance: "high",
            now: now
        )
        let omitted = try CreateQuestIntent.creationInput(
            title: "Default priority shortcut quest",
            details: nil,
            deadline: nil,
            importance: nil,
            now: now
        )

        #expect(low.importance == .low)
        #expect(medium.importance == .medium)
        #expect(high.importance == .high)
        #expect(omitted.importance == .medium)
    }

    @Test("unknown raw importance is rejected instead of using the medium default")
    func rejectsUnknownRawImportance() {
        #expect(throws: CreateQuestIntentError.invalidImportance) {
            try CreateQuestIntent.creationInput(
                title: "Unknown priority shortcut quest",
                details: nil,
                deadline: nil,
                importance: "urgent",
                now: now
            )
        }
    }

    @Test("importance options expose localized low medium high raw values in order")
    func exposesLocalizedImportanceOptions() async throws {
        let options = try await ShortcutQuestImportanceOptionsProvider().results()
        let items = options.sections.flatMap(\.items)

        #expect(items.map(\.value) == ["low", "medium", "high"])
        #expect(items.map { AppStrings.resolve($0.description.title, locale: Locale(identifier: "en")) } == ["Low", "Medium", "High"])
        #expect(items.map { AppStrings.resolve($0.description.title, locale: Locale(identifier: "ko")) } == ["낮음", "보통", "높음"])
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
