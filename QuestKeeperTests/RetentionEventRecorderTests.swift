import Foundation
import SwiftData
import Testing
@testable import QuestKeeper

@MainActor
struct RetentionEventRecorderTests {
    private let installationID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private let questID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    private let actionID = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test("independent callers converge on one persisted installation identity")
    nonisolated func installationIdentityIsRaceSafe() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appending(path: "retention-installation-id-v1")

        let identities = try await withThrowingTaskGroup(of: UUID.self) { group in
            for _ in 0..<8 {
                group.addTask {
                    try RetentionInstallationIdentityStore(fileURL: fileURL).loadOrCreate()
                }
            }
            var result: Set<UUID> = []
            while let identity = try await group.next() {
                result.insert(identity)
            }
            return result
        }

        #expect(identities.count == 1)
    }

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
        #expect(RetentionEventRecorder.recordExperimentExposed(
            experimentKey: OnboardingExperiment.key,
            at: now,
            in: context
        ) == .inserted)
        #expect(RetentionEventRecorder.recordExperimentExposed(
            experimentKey: OnboardingExperiment.key,
            at: now.addingTimeInterval(1),
            in: context
        ) == .duplicate)
        #expect(RetentionEventRecorder.recordQuestCreationStarted(
            experimentKey: OnboardingExperiment.key,
            actionID: actionID,
            at: now,
            in: context
        ) == .inserted)
        #expect(RetentionEventRecorder.recordQuestCreationStarted(
            experimentKey: OnboardingExperiment.key,
            actionID: actionID,
            at: now.addingTimeInterval(1),
            in: context
        ) == .duplicate)
        #expect(RetentionEventRecorder.recordOnboardingDeferred(
            experimentKey: OnboardingExperiment.key,
            sessionID: sessionID,
            at: now,
            in: context
        ) == .inserted)
        #expect(RetentionEventRecorder.recordOnboardingDeferred(
            experimentKey: OnboardingExperiment.key,
            sessionID: sessionID,
            at: now.addingTimeInterval(1),
            in: context
        ) == .duplicate)

        let events = try context.fetch(FetchDescriptor<RetentionEvent>())
        #expect(events.count == 6)
        #expect(Set(events.map(\.installationID)) == [installationID])
        let experimentEvents = events.filter {
            [.experimentExposed, .questCreationStarted, .onboardingDeferred].contains($0.snapshot.name)
        }
        #expect(experimentEvents.count == 3)
        #expect(experimentEvents.allSatisfy { $0.snapshot.source == .app })
        #expect(experimentEvents.allSatisfy { $0.snapshot.questID == nil })
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

    @Test("retry identity deduplicates one attempt while preserving later attempts")
    func retryCanonicalIdentity() throws {
        let container = try measurementContainer()
        let context = container.mainContext
        context.insert(RetentionInstallation(installationID: installationID, measurementStartedAt: now))

        #expect(RetentionEventRecorder.recordQuestRetried(
            questID: questID,
            attemptID: actionID,
            at: now,
            in: context
        ) == .inserted)
        #expect(RetentionEventRecorder.recordQuestRetried(
            questID: questID,
            attemptID: actionID,
            at: now.addingTimeInterval(1),
            in: context
        ) == .duplicate)
        #expect(RetentionEventRecorder.recordQuestRetried(
            questID: questID,
            attemptID: sessionID,
            at: now.addingTimeInterval(2),
            in: context
        ) == .inserted)

        let events = try context.fetch(FetchDescriptor<RetentionEvent>())
        #expect(Set(events.map(\.deduplicationKey)) == [
            "quest_retried:\(installationID):\(questID):\(actionID)",
            "quest_retried:\(installationID):\(questID):\(sessionID)",
        ])
    }

    private func measurementContainer() throws -> ModelContainer {
        let schema = Schema([Quest.self, RetentionInstallation.self, RetentionEvent.self])
        return try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
    }
}
