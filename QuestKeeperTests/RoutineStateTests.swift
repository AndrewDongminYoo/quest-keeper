import Foundation
import Testing
@testable import QuestKeeper

struct RoutineStateTests {
    private let seoulCalendar = DailyFocusDay.gregorianCalendar(
        timeZone: TimeZone(identifier: "Asia/Seoul")!
    )

    @Test("daily roster caps at two, ignores input order, and rotates by local day")
    func capsAndRotatesDailyRoster() {
        let now = date(year: 2026, month: 8, day: 30, hour: 12, calendar: seoulCalendar)
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let thirdID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        let rules = [
            rule(id: thirdID, createdAt: now.addingTimeInterval(-60)),
            rule(id: firstID, createdAt: now.addingTimeInterval(-60)),
            rule(id: secondID, createdAt: now.addingTimeInterval(-60)),
        ]
        let expectedToday = [firstID, secondID]
        let tomorrow = seoulCalendar.date(byAdding: .day, value: 1, to: now)!
        let expectedTomorrow = [secondID, thirdID]

        #expect(RoutineState.visibleRoutineIDs(
            rules: rules,
            completions: [],
            now: now,
            calendar: seoulCalendar
        ) == expectedToday)
        #expect(RoutineState.visibleRoutineIDs(
            rules: Array(rules.reversed()),
            completions: [],
            now: tomorrow,
            calendar: seoulCalendar
        ) == expectedTomorrow)
    }

    @Test("a completed roster row hides today without filling from another rule")
    func hidesCompletedRoutineWithoutReplacement() {
        let now = date(year: 2026, month: 8, day: 30, hour: 12, calendar: seoulCalendar)
        let rules = (1...3).map { offset in
            rule(
                id: UUID(uuidString: "00000000-0000-0000-0000-00000000000\(offset)")!,
                createdAt: now.addingTimeInterval(-60)
            )
        }
        let initialRoster = RoutineState.visibleRoutineIDs(
            rules: rules,
            completions: [],
            now: now,
            calendar: seoulCalendar
        )
        let completion = RoutineCompletionSnapshot(
            id: UUID(),
            routineID: initialRoster[0],
            localDayKey: DailyFocusDay.key(for: now, calendar: seoulCalendar),
            timeZoneIdentifier: seoulCalendar.timeZone.identifier,
            completedAt: now
        )

        #expect(RoutineState.visibleRoutineIDs(
            rules: rules,
            completions: [completion],
            now: now,
            calendar: seoulCalendar
        ) == [initialRoster[1]])
    }

    @Test("daily roster rotates at the local midnight boundary")
    func rotatesAtLocalMidnight() {
        let beforeMidnight = date(year: 2026, month: 8, day: 29, hour: 23, calendar: seoulCalendar)
        let afterMidnight = date(year: 2026, month: 8, day: 30, hour: 0, calendar: seoulCalendar)
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let thirdID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        let rules = [firstID, secondID, thirdID].map {
            rule(id: $0, createdAt: beforeMidnight.addingTimeInterval(-60))
        }

        #expect(RoutineState.visibleRoutineIDs(
            rules: rules,
            completions: [],
            now: beforeMidnight,
            calendar: seoulCalendar
        ) == [thirdID, firstID])
        #expect(RoutineState.visibleRoutineIDs(
            rules: rules,
            completions: [],
            now: afterMidnight,
            calendar: seoulCalendar
        ) == [firstID, secondID])
    }

    @Test("a completion hides only its current local day")
    func reentersOnTheNextLocalDay() {
        let now = date(year: 2026, month: 8, day: 30, hour: 23, calendar: seoulCalendar)
        let rule = rule(id: UUID(), createdAt: now.addingTimeInterval(-60))
        let completion = RoutineCompletionSnapshot(
            id: UUID(),
            routineID: rule.id,
            localDayKey: DailyFocusDay.key(for: now, calendar: seoulCalendar),
            timeZoneIdentifier: seoulCalendar.timeZone.identifier,
            completedAt: now
        )
        let tomorrow = seoulCalendar.date(byAdding: .day, value: 1, to: now)!

        #expect(RoutineState.visibleRoutineIDs(
            rules: [rule],
            completions: [completion],
            now: now,
            calendar: seoulCalendar
        ).isEmpty)
        #expect(RoutineState.visibleRoutineIDs(
            rules: [rule],
            completions: [completion],
            now: tomorrow,
            calendar: seoulCalendar
        ) == [rule.id])
    }

    @Test("local day identity handles Seoul midnight and a daylight-saving day")
    func usesInjectedLocalCalendar() {
        let seoulNow = date(year: 2026, month: 8, day: 30, hour: 0, calendar: seoulCalendar)
        let seoulRule = rule(id: UUID(), createdAt: seoulNow.addingTimeInterval(-86_400))
        let yesterdayCompletion = RoutineCompletionSnapshot(
            id: UUID(),
            routineID: seoulRule.id,
            localDayKey: DailyFocusDay.key(
                for: seoulNow.addingTimeInterval(-60),
                calendar: seoulCalendar
            ),
            timeZoneIdentifier: seoulCalendar.timeZone.identifier,
            completedAt: seoulNow.addingTimeInterval(-60)
        )

        let losAngelesCalendar = DailyFocusDay.gregorianCalendar(
            timeZone: TimeZone(identifier: "America/Los_Angeles")!
        )
        let dstNow = date(year: 2026, month: 3, day: 8, hour: 12, calendar: losAngelesCalendar)
        let dstRule = rule(id: UUID(), createdAt: dstNow.addingTimeInterval(-86_400))
        let dstCompletion = RoutineCompletionSnapshot(
            id: UUID(),
            routineID: dstRule.id,
            localDayKey: DailyFocusDay.key(for: dstNow, calendar: losAngelesCalendar),
            timeZoneIdentifier: losAngelesCalendar.timeZone.identifier,
            completedAt: date(year: 2026, month: 3, day: 8, hour: 1, calendar: losAngelesCalendar)
        )

        #expect(RoutineState.visibleRoutineIDs(
            rules: [seoulRule],
            completions: [yesterdayCompletion],
            now: seoulNow,
            calendar: seoulCalendar
        ) == [seoulRule.id])
        #expect(RoutineState.visibleRoutineIDs(
            rules: [dstRule],
            completions: [dstCompletion],
            now: dstNow,
            calendar: losAngelesCalendar
        ).isEmpty)
    }

    private func rule(id: UUID, createdAt: Date) -> RoutineRuleSnapshot {
        RoutineRuleSnapshot(id: id, createdAt: createdAt)
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        calendar: Calendar
    ) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
