import Foundation
import Testing
@testable import QuestKeeper

struct DailyFocusStateTests {
    private let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
    private let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
    private let thirdID = UUID(uuidString: "00000000-0000-0000-0000-000000000103")!
    private let fourthID = UUID(uuidString: "00000000-0000-0000-0000-000000000104")!
    private let installationID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let now = Date(timeIntervalSince1970: 1_782_230_400)

    @Test("recommendation ranks deadline then importance then UUID and caps at three")
    func deterministicRecommendation() {
        let equalDeadline = now.addingTimeInterval(300)
        let quests = [
            quest(fourthID, deadline: now.addingTimeInterval(600), importance: .high),
            quest(thirdID, deadline: equalDeadline, importance: .medium),
            quest(secondID, deadline: equalDeadline, importance: .high),
            quest(firstID, deadline: equalDeadline, importance: .high),
        ]

        #expect(DailyFocusState.recommend(quests: quests, now: now) == [
            firstID, secondID, thirdID,
        ])
    }

    @Test("recommendation excludes completed and expired quests")
    func recommendationExcludesResolvedQuests() {
        let quests = [
            quest(firstID, deadline: now.addingTimeInterval(60), importance: .low),
            quest(
                secondID,
                deadline: now.addingTimeInterval(60),
                importance: .high,
                completedAt: now.addingTimeInterval(-60)
            ),
            quest(thirdID, deadline: now.addingTimeInterval(-1), importance: .high),
        ]

        #expect(DailyFocusState.recommend(quests: quests, now: now) == [firstID])
    }

    @Test("disabled and empty states never synthesize selection")
    func disabledAndEmptyStates() {
        #expect(DailyFocusState.make(
            enabled: false,
            quests: [quest(firstID, deadline: now.addingTimeInterval(60), importance: .low)],
            selections: [],
            now: now,
            calendar: seoulCalendar
        ) == .disabled)
        #expect(DailyFocusState.make(
            enabled: true,
            quests: [],
            selections: [],
            now: now,
            calendar: seoulCalendar
        ) == .empty)
    }

    @Test("latest revision controls visible selection while completion remains")
    func latestRevisionAndCompletion() throws {
        let confirmation = try selection(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000201")!,
            questIDs: [firstID, secondID],
            recordedAt: now.addingTimeInterval(-120),
            kind: .confirmation
        )
        let revision = try selection(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000202")!,
            questIDs: [secondID, thirdID],
            recordedAt: now.addingTimeInterval(-60),
            kind: .revision
        )
        let completedAt = now.addingTimeInterval(-30)
        let quests = [
            quest(firstID, deadline: now.addingTimeInterval(600), importance: .low),
            quest(secondID, deadline: now.addingTimeInterval(600), importance: .medium, completedAt: completedAt),
            quest(thirdID, deadline: now.addingTimeInterval(600), importance: .high),
        ]

        #expect(DailyFocusState.make(
            enabled: true,
            quests: quests,
            selections: [revision, confirmation],
            now: now,
            calendar: seoulCalendar
        ) == .confirmed(
            selectedQuestIDs: [secondID, thirdID],
            completedQuestIDs: [secondID]
        ))
    }

    @Test("deleted selected quests are filtered without erasing confirmation")
    func deletedSelectionIsFiltered() throws {
        let confirmation = try selection(
            questIDs: [firstID],
            recordedAt: now.addingTimeInterval(-60),
            kind: .confirmation
        )

        #expect(DailyFocusState.make(
            enabled: true,
            quests: [],
            selections: [confirmation],
            now: now,
            calendar: seoulCalendar
        ) == .confirmed(selectedQuestIDs: [], completedQuestIDs: []))
    }

    @Test("a prior local day selection does not carry forward")
    func nextDayResetsSelection() throws {
        let yesterday = now.addingTimeInterval(-86_400)
        let oldSelection = try selection(
            questIDs: [firstID],
            recordedAt: yesterday,
            kind: .confirmation
        )
        let pending = quest(firstID, deadline: now.addingTimeInterval(600), importance: .low)

        #expect(DailyFocusState.make(
            enabled: true,
            quests: [pending],
            selections: [oldSelection],
            now: now,
            calendar: seoulCalendar
        ) == .recommended([firstID]))
    }

    @Test("selection validation and remaining partition are pure")
    func validationAndPartition() {
        #expect(!DailyFocusState.isValidSelection([]))
        #expect(DailyFocusState.isValidSelection([firstID]))
        #expect(DailyFocusState.isValidSelection([firstID, secondID, thirdID]))
        #expect(!DailyFocusState.isValidSelection([firstID, secondID, thirdID, fourthID]))
        #expect(!DailyFocusState.isValidSelection([firstID, firstID]))
        #expect(DailyFocusState.remainingPendingQuestIDs(
            pendingQuestIDs: [firstID, secondID, thirdID],
            selectedQuestIDs: [secondID]
        ) == [firstID, thirdID])
    }

    private var seoulCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    private func quest(
        _ id: UUID,
        deadline: Date,
        importance: Importance,
        completedAt: Date? = nil
    ) -> QuestSnapshot {
        QuestSnapshot(
            id: id,
            deadline: deadline,
            completedAt: completedAt,
            importance: importance
        )
    }

    private func selection(
        id: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000200")!,
        questIDs: [UUID],
        recordedAt: Date,
        kind: DailyFocusSelectionKind
    ) throws -> DailyFocusSelectionSnapshot {
        DailyFocusSelectionSnapshot(
            id: id,
            schemaVersion: 1,
            installationID: installationID,
            localDayKey: DailyFocusDay.key(for: recordedAt, calendar: seoulCalendar),
            timeZoneIdentifier: seoulCalendar.timeZone.identifier,
            selectedQuestIDsData: try JSONEncoder().encode(questIDs.map(\.uuidString)),
            recordedAt: recordedAt,
            kindRawValue: kind.rawValue
        )
    }
}
