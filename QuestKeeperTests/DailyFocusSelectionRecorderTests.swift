import Foundation
import SwiftData
import Testing
@testable import QuestKeeper

@MainActor
struct DailyFocusSelectionRecorderTests {
    private let installationID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let firstQuestID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
    private let secondQuestID = UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
    private let thirdQuestID = UUID(uuidString: "00000000-0000-0000-0000-000000000103")!
    private let fourthQuestID = UUID(uuidString: "00000000-0000-0000-0000-000000000104")!
    private let recordedAt = Date(timeIntervalSince1970: 1_782_226_800)

    @Test("first confirmation stores one immutable ordered snapshot")
    func recordsConfirmation() throws {
        let container = try makeContainer()
        insertInstallationAndQuests(in: container.mainContext)

        let result = DailyFocusSelectionRecorder.record(
            selectedQuestIDs: [secondQuestID, firstQuestID],
            kind: .confirmation,
            at: recordedAt,
            calendar: seoulCalendar,
            in: container.mainContext
        )

        guard case let .inserted(snapshot) = result else {
            Issue.record("Expected inserted snapshot")
            return
        }
        #expect(snapshot.schemaVersion == 1)
        #expect(snapshot.installationID == installationID)
        #expect(snapshot.localDayKey == "2026-06-24")
        #expect(snapshot.timeZoneIdentifier == "Asia/Seoul")
        #expect(snapshot.selectedQuestIDs == [firstQuestID, secondQuestID])
        #expect(snapshot.recordedAt == recordedAt)
        #expect(snapshot.kind == .confirmation)

        let rows = try container.mainContext.fetch(FetchDescriptor<DailyFocusSelection>())
        #expect(rows.count == 1)
        #expect(rows.first?.snapshot == snapshot)
    }

    @Test("same logical selection is a no-op")
    func duplicateSelectionIsUnchanged() throws {
        let container = try makeContainer()
        insertInstallationAndQuests(in: container.mainContext)

        let first = DailyFocusSelectionRecorder.record(
            selectedQuestIDs: [secondQuestID, firstQuestID],
            kind: .confirmation,
            at: recordedAt,
            calendar: seoulCalendar,
            in: container.mainContext
        )
        let duplicate = DailyFocusSelectionRecorder.record(
            selectedQuestIDs: [firstQuestID, secondQuestID],
            kind: .confirmation,
            at: recordedAt.addingTimeInterval(10),
            calendar: seoulCalendar,
            in: container.mainContext
        )

        guard case let .inserted(firstSnapshot) = first,
              case let .unchanged(duplicateSnapshot) = duplicate else {
            Issue.record("Expected inserted then unchanged")
            return
        }
        #expect(firstSnapshot == duplicateSnapshot)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<DailyFocusSelection>()) == 1)
    }

    @Test("revision appends without mutating the confirmation")
    func recordsRevision() throws {
        let container = try makeContainer()
        insertInstallationAndQuests(in: container.mainContext)

        let confirmation = DailyFocusSelectionRecorder.record(
            selectedQuestIDs: [firstQuestID],
            kind: .confirmation,
            at: recordedAt,
            calendar: seoulCalendar,
            in: container.mainContext
        )
        let revision = DailyFocusSelectionRecorder.record(
            selectedQuestIDs: [secondQuestID],
            kind: .revision,
            at: recordedAt.addingTimeInterval(60),
            calendar: seoulCalendar,
            in: container.mainContext
        )

        guard case let .inserted(confirmationSnapshot) = confirmation,
              case let .inserted(revisionSnapshot) = revision else {
            Issue.record("Expected confirmation and revision inserts")
            return
        }
        #expect(confirmationSnapshot.selectedQuestIDs == [firstQuestID])
        #expect(confirmationSnapshot.kind == .confirmation)
        #expect(revisionSnapshot.selectedQuestIDs == [secondQuestID])
        #expect(revisionSnapshot.kind == .revision)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<DailyFocusSelection>()) == 2)
    }

    @Test(
        "invalid selections fail without inserting",
        arguments: [
            [UUID](),
            [
                UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
                UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
            ],
            [
                UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
                UUID(uuidString: "00000000-0000-0000-0000-000000000102")!,
                UUID(uuidString: "00000000-0000-0000-0000-000000000103")!,
                UUID(uuidString: "00000000-0000-0000-0000-000000000104")!,
            ],
        ]
    )
    func rejectsInvalidSelection(selectedQuestIDs: [UUID]) throws {
        let container = try makeContainer()
        insertInstallationAndQuests(in: container.mainContext)

        let result = DailyFocusSelectionRecorder.record(
            selectedQuestIDs: selectedQuestIDs,
            kind: .confirmation,
            at: recordedAt,
            calendar: seoulCalendar,
            in: container.mainContext
        )

        #expect(result == .failed)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<DailyFocusSelection>()) == 0)
    }

    @Test("revision before confirmation fails")
    func rejectsRevisionBeforeConfirmation() throws {
        let container = try makeContainer()
        insertInstallationAndQuests(in: container.mainContext)

        let result = DailyFocusSelectionRecorder.record(
            selectedQuestIDs: [firstQuestID],
            kind: .revision,
            at: recordedAt,
            calendar: seoulCalendar,
            in: container.mainContext
        )

        #expect(result == .failed)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<DailyFocusSelection>()) == 0)
    }

    @Test("backdated and same-time revisions fail")
    func rejectsNonLaterRevision() throws {
        let container = try makeContainer()
        insertInstallationAndQuests(in: container.mainContext)
        #expect(DailyFocusSelectionRecorder.record(
            selectedQuestIDs: [firstQuestID],
            kind: .confirmation,
            at: recordedAt,
            calendar: seoulCalendar,
            in: container.mainContext
        ) != .failed)

        for invalidDate in [recordedAt.addingTimeInterval(-1), recordedAt] {
            #expect(DailyFocusSelectionRecorder.record(
                selectedQuestIDs: [secondQuestID],
                kind: .revision,
                at: invalidDate,
                calendar: seoulCalendar,
                in: container.mainContext
            ) == .failed)
        }
        #expect(try container.mainContext.fetchCount(FetchDescriptor<DailyFocusSelection>()) == 1)
    }

    @Test("same Gregorian local date remains one focus day after time-zone change")
    func preventsSecondConfirmationForSameDateInAnotherTimeZone() throws {
        let container = try makeContainer()
        insertInstallationAndQuests(in: container.mainContext)
        #expect(DailyFocusSelectionRecorder.record(
            selectedQuestIDs: [firstQuestID],
            kind: .confirmation,
            at: recordedAt,
            calendar: seoulCalendar,
            in: container.mainContext
        ) != .failed)
        var tokyoCalendar = Calendar(identifier: .japanese)
        tokyoCalendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!

        #expect(DailyFocusSelectionRecorder.record(
            selectedQuestIDs: [secondQuestID],
            kind: .confirmation,
            at: recordedAt.addingTimeInterval(60),
            calendar: tokyoCalendar,
            in: container.mainContext
        ) == .failed)
    }

    @Test("revision can retain a focus quest completed on the same day")
    func revisionRetainsCompletedMember() throws {
        let container = try makeContainer()
        insertInstallationAndQuests(in: container.mainContext)
        #expect(DailyFocusSelectionRecorder.record(
            selectedQuestIDs: [firstQuestID, secondQuestID],
            kind: .confirmation,
            at: recordedAt,
            calendar: seoulCalendar,
            in: container.mainContext
        ) != .failed)
        let quests = try container.mainContext.fetch(FetchDescriptor<Quest>())
        quests.first(where: { $0.id == firstQuestID })?.completedAt = recordedAt.addingTimeInterval(30)

        let result = DailyFocusSelectionRecorder.record(
            selectedQuestIDs: [firstQuestID, thirdQuestID],
            kind: .revision,
            at: recordedAt.addingTimeInterval(60),
            calendar: seoulCalendar,
            in: container.mainContext
        )

        #expect(result != .failed)
        #expect(result.snapshot?.selectedQuestIDs?.contains(firstQuestID) == true)
    }

    private var seoulCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Quest.self,
            RetentionInstallation.self,
            RetentionEvent.self,
            ExperimentAssignment.self,
            DailyFocusSelection.self,
        ])
        return try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
    }

    private func insertInstallationAndQuests(in context: ModelContext) {
        context.insert(RetentionInstallation(
            installationID: installationID,
            measurementStartedAt: recordedAt.addingTimeInterval(-60)
        ))
        context.insert(Quest(
            id: firstQuestID,
            title: "첫 번째",
            deadline: recordedAt.addingTimeInterval(60),
            importance: .low
        ))
        context.insert(Quest(
            id: secondQuestID,
            title: "두 번째",
            deadline: recordedAt.addingTimeInterval(120),
            importance: .high
        ))
        context.insert(Quest(
            id: thirdQuestID,
            title: "세 번째",
            deadline: recordedAt.addingTimeInterval(180),
            importance: .medium
        ))
        context.insert(Quest(
            id: fourthQuestID,
            title: "네 번째",
            deadline: recordedAt.addingTimeInterval(240),
            importance: .low
        ))
        try? context.save()
    }
}

private extension DailyFocusSelectionRecordResult {
    var snapshot: DailyFocusSelectionSnapshot? {
        switch self {
        case .inserted(let snapshot), .unchanged(let snapshot): snapshot
        case .failed: nil
        }
    }
}
