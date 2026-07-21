import Foundation
import SwiftData
import Testing
@testable import QuestKeeper

@MainActor
struct RetentionEventRecorderTests {
    private let installationID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private let questID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test("recorder creates one stable installation and deduplicates each canonical key")
    func recorderDeduplicatesCanonicalKeys() throws {
        let container = try measurementContainer()
        let context = container.mainContext
        context.insert(RetentionInstallation(installationID: installationID, measurementStartedAt: now))

        #expect(RetentionEventRecorder.recordActivation(sessionID: sessionID, at: now, in: context) == .inserted)
        #expect(RetentionEventRecorder.recordActivation(sessionID: sessionID, at: now, in: context) == .duplicate)
        #expect(RetentionEventRecorder.recordQuestCreated(questID: questID, at: now, in: context) == .inserted)
        #expect(RetentionEventRecorder.recordQuestCreated(questID: questID, at: now, in: context) == .duplicate)
        #expect(RetentionEventRecorder.recordQuestCompleted(
            questID: questID,
            completedAt: now,
            source: .app,
            in: context
        ) == .inserted)
        #expect(RetentionEventRecorder.recordQuestCompleted(
            questID: questID,
            completedAt: now,
            source: .app,
            in: context
        ) == .duplicate)

        let events = try context.fetch(FetchDescriptor<RetentionEvent>())
        #expect(events.count == 3)
        #expect(Set(events.map(\.installationID)) == [installationID])
    }

    @Test("completion identity ignores process source but includes completion time")
    func completionCanonicalIdentity() throws {
        let container = try measurementContainer()
        let context = container.mainContext

        #expect(RetentionEventRecorder.recordQuestCompleted(
            questID: questID,
            completedAt: now,
            source: .app,
            in: context
        ) == .inserted)
        #expect(RetentionEventRecorder.recordQuestCompleted(
            questID: questID,
            completedAt: now,
            source: .widget,
            in: context
        ) == .duplicate)
        #expect(RetentionEventRecorder.recordQuestCompleted(
            questID: questID,
            completedAt: now.addingTimeInterval(1),
            source: .widget,
            in: context
        ) == .inserted)

        let events = try context.fetch(FetchDescriptor<RetentionEvent>())
        #expect(events.count == 2)
        #expect(events.map(\.snapshot).allSatisfy { $0.name == .questCompleted })
    }

    @Test("retry identity includes the effective new deadline")
    func retryCanonicalIdentity() throws {
        let container = try measurementContainer()
        let context = container.mainContext
        let firstDeadline = now.addingTimeInterval(86_400)
        let secondDeadline = firstDeadline.addingTimeInterval(86_400)

        #expect(RetentionEventRecorder.recordQuestRetried(
            questID: questID,
            newDeadline: firstDeadline,
            at: now,
            in: context
        ) == .inserted)
        #expect(RetentionEventRecorder.recordQuestRetried(
            questID: questID,
            newDeadline: firstDeadline,
            at: now.addingTimeInterval(1),
            in: context
        ) == .duplicate)
        #expect(RetentionEventRecorder.recordQuestRetried(
            questID: questID,
            newDeadline: secondDeadline,
            at: now.addingTimeInterval(1),
            in: context
        ) == .inserted)
    }

    private func measurementContainer() throws -> ModelContainer {
        let schema = Schema([Quest.self, RetentionInstallation.self, RetentionEvent.self])
        return try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
    }
}
