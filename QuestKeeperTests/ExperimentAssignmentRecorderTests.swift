import Foundation
import SwiftData
import Testing
@testable import QuestKeeper

@MainActor
struct ExperimentAssignmentRecorderTests {
    private let installationID = UUID(uuidString: "00000000-0000-0000-0000-000000000034")!
    private let assignedAt = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test("eligible installation receives the injected variant once")
    func eligibleInstallationIsAssignedOnce() throws {
        let container = try experimentContainer()

        let first = ExperimentAssignmentRecorder.enrollIfEligible(
            at: assignedAt,
            in: container.mainContext,
            installationIDProvider: { installationID },
            variantSelector: { .guided }
        )
        let second = ExperimentAssignmentRecorder.enrollIfEligible(
            at: assignedAt.addingTimeInterval(10),
            in: container.mainContext,
            installationIDProvider: { UUID() },
            variantSelector: { .control }
        )

        #expect(first.assignment?.variant == .guided)
        #expect(second.assignment == first.assignment)
        #expect(try container.mainContext.fetch(FetchDescriptor<ExperimentAssignment>()).count == 1)
        #expect(try container.mainContext.fetch(FetchDescriptor<RetentionInstallation>()).count == 1)
    }

    @Test("existing measurement installation is not backfilled")
    func existingInstallationIsIneligible() throws {
        let container = try experimentContainer()
        container.mainContext.insert(RetentionInstallation(
            installationID: installationID,
            measurementStartedAt: assignedAt
        ))
        try container.mainContext.save()

        let result = ExperimentAssignmentRecorder.enrollIfEligible(
            at: assignedAt,
            in: container.mainContext,
            installationIDProvider: { UUID() },
            variantSelector: { .guided }
        )

        #expect(result == .ineligible)
        #expect(try container.mainContext.fetch(FetchDescriptor<ExperimentAssignment>()).isEmpty)
    }

    @Test("store containing a quest is not enrolled")
    func existingQuestIsIneligible() throws {
        let container = try experimentContainer()
        container.mainContext.insert(Quest(
            title: "기존 퀘스트",
            deadline: assignedAt.addingTimeInterval(3_600),
            importance: .medium
        ))
        try container.mainContext.save()

        let result = ExperimentAssignmentRecorder.enrollIfEligible(
            at: assignedAt,
            in: container.mainContext,
            installationIDProvider: { installationID },
            variantSelector: { .guided }
        )

        #expect(result == .ineligible)
        #expect(try container.mainContext.fetch(FetchDescriptor<ExperimentAssignment>()).isEmpty)
        #expect(try container.mainContext.fetch(FetchDescriptor<RetentionInstallation>()).isEmpty)
    }

    @Test("identity failure inserts no partial enrollment")
    func identityFailureLeavesNoRows() throws {
        let container = try experimentContainer()

        let result = ExperimentAssignmentRecorder.enrollIfEligible(
            at: assignedAt,
            in: container.mainContext,
            installationIDProvider: { throw TestError.identityUnavailable },
            variantSelector: { .guided }
        )

        #expect(result == .failed)
        #expect(try container.mainContext.fetch(FetchDescriptor<ExperimentAssignment>()).isEmpty)
        #expect(try container.mainContext.fetch(FetchDescriptor<RetentionInstallation>()).isEmpty)
    }

    @Test("conflicting assignment rows fail closed")
    func conflictingAssignmentsFailClosed() throws {
        let container = try experimentContainer()
        container.mainContext.insert(RetentionInstallation(
            installationID: installationID,
            measurementStartedAt: assignedAt
        ))
        container.mainContext.insert(ExperimentAssignment(
            installationID: installationID,
            variant: .control,
            assignedAt: assignedAt
        ))
        container.mainContext.insert(ExperimentAssignment(
            installationID: installationID,
            variant: .guided,
            assignedAt: assignedAt
        ))
        try container.mainContext.save()

        let result = ExperimentAssignmentRecorder.enrollIfEligible(
            at: assignedAt.addingTimeInterval(10),
            in: container.mainContext
        )

        #expect(result == .failed)
        #expect(try container.mainContext.fetch(FetchDescriptor<ExperimentAssignment>()).count == 2)
    }

    private func experimentContainer() throws -> ModelContainer {
        let schema = Schema([
            Quest.self,
            RetentionInstallation.self,
            RetentionEvent.self,
            ExperimentAssignment.self,
        ])
        return try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
    }

    private enum TestError: Error {
        case identityUnavailable
    }
}
