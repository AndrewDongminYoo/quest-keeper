import Foundation
import SwiftData

nonisolated enum RoutineCompletionRecordResult: Equatable, Sendable {
    case inserted(RoutineCompletionSnapshot)
    case unchanged(RoutineCompletionSnapshot)
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
            guard rules.contains(where: { $0.id == routineID }) else { return .failed }

            let localDayKey = DailyFocusDay.key(for: completedAt, calendar: calendar)
            let completions = try context.fetch(FetchDescriptor<RoutineCompletion>())
            if let existing = completions.first(where: {
                $0.routineID == routineID && $0.localDayKey == localDayKey
            }) {
                return .unchanged(existing.snapshot)
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
