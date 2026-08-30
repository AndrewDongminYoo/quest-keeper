import Foundation
import SwiftData
import Testing
@testable import QuestKeeper

@MainActor
struct RoutineCompletionRecorderTests {
    private let calendar = DailyFocusDay.gregorianCalendar(
        timeZone: TimeZone(identifier: "Asia/Seoul")!
    )

    @Test("one routine records at most one completion fact per local day")
    func recordsIdempotentlyPerLocalDay() throws {
        let container = QuestModelContainer.makeEphemeralFallback()
        let context = ModelContext(container)
        let now = date(year: 2026, month: 8, day: 30, hour: 12)
        let rule = RoutineRule(title: "Take medicine", createdAt: now.addingTimeInterval(-60))
        context.insert(rule)
        try context.save()

        let first = RoutineCompletionRecorder.record(
            routineID: rule.id,
            at: now,
            calendar: calendar,
            in: context
        )
        let duplicate = RoutineCompletionRecorder.record(
            routineID: rule.id,
            at: now.addingTimeInterval(60),
            calendar: calendar,
            in: context
        )
        let completions = try context.fetch(FetchDescriptor<RoutineCompletion>())

        #expect(first.snapshot?.routineID == rule.id)
        #expect(duplicate.snapshot?.id == first.snapshot?.id)
        #expect(completions.count == 1)
        #expect(completions[0].localDayKey == DailyFocusDay.key(for: now, calendar: calendar))
    }

    @Test("the next local day records a new immutable completion")
    func recordsAgainOnTheNextLocalDay() throws {
        let container = QuestModelContainer.makeEphemeralFallback()
        let context = ModelContext(container)
        let now = date(year: 2026, month: 8, day: 30, hour: 23)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        let rule = RoutineRule(title: "Stretch", createdAt: now.addingTimeInterval(-60))
        context.insert(rule)
        try context.save()

        let today = RoutineCompletionRecorder.record(
            routineID: rule.id,
            at: now,
            calendar: calendar,
            in: context
        )
        let nextDay = RoutineCompletionRecorder.record(
            routineID: rule.id,
            at: tomorrow,
            calendar: calendar,
            in: context
        )
        let completions = try context.fetch(FetchDescriptor<RoutineCompletion>())

        #expect(today.snapshot?.id != nextDay.snapshot?.id)
        #expect(completions.count == 2)
        #expect(Set(completions.map(\.localDayKey)).count == 2)
    }

    @Test("a deleted or unknown rule cannot receive a completion")
    func refusesUnknownRule() throws {
        let container = QuestModelContainer.makeEphemeralFallback()
        let context = ModelContext(container)

        #expect(RoutineCompletionRecorder.record(
            routineID: UUID(),
            at: date(year: 2026, month: 8, day: 30, hour: 12),
            calendar: calendar,
            in: context
        ) == .failed)
        #expect(try context.fetch(FetchDescriptor<RoutineCompletion>()).isEmpty)
    }

    private func date(year: Int, month: Int, day: Int, hour: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}

private extension RoutineCompletionRecordResult {
    var snapshot: RoutineCompletionSnapshot? {
        switch self {
        case .inserted(let snapshot), .unchanged(let snapshot):
            snapshot
        case .failed:
            nil
        }
    }
}
