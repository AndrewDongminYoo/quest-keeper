import Foundation
import SwiftData

nonisolated enum RoutineCompletionRecordResult: Equatable, Sendable {
    case inserted(RoutineCompletionSnapshot)
    case unchanged(RoutineCompletionSnapshot)
    /// The completion does not apply: the rule is gone, or the routine rotated out of today's
    /// roster. Nothing was written and nothing is wrong with the store, so a caller must not report
    /// this as a refused write — a tap on a board that has not refreshed past local midnight lands
    /// here, and telling the user their save failed would send them to retry something that cannot
    /// succeed.
    case rejected
    /// The store refused the write.
    case failed
}

@MainActor
enum RoutineCompletionRecorder {
    static func record(
        routineID: UUID,
        at completedAt: Date,
        calendar: Calendar,
        in context: ModelContext
    ) -> RoutineCompletionRecordResult {
        do {
            let rules = try context.fetch(FetchDescriptor<RoutineRule>())
            guard rules.contains(where: { $0.id == routineID }) else { return .rejected }

            let localDayKey = DailyFocusDay.key(for: completedAt, calendar: calendar)
            let completions = try context.fetch(FetchDescriptor<RoutineCompletion>())
            if let existing = completions.first(where: {
                $0.routineID == routineID && $0.localDayKey == localDayKey
            }) {
                return .unchanged(existing.snapshot)
            }
            guard RoutineState.visibleRoutineIDs(
                rules: rules.map(\.snapshot),
                completions: completions.map(\.snapshot),
                now: completedAt,
                calendar: calendar
            ).contains(routineID) else {
                return .rejected
            }

            let completion = RoutineCompletion(
                routineID: routineID,
                localDayKey: localDayKey,
                timeZoneIdentifier: calendar.timeZone.identifier,
                completedAt: completedAt
            )
            context.insert(completion)
            do {
                try context.save()
                return .inserted(completion.snapshot)
            } catch {
                context.delete(completion)
                throw error
            }
        } catch {
            return .failed
        }
    }
}
