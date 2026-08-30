import Foundation

nonisolated enum RoutineState {
    static let maximumVisibleRoutines = 2

    static func visibleRoutineIDs(
        rules: [RoutineRuleSnapshot],
        completions: [RoutineCompletionSnapshot],
        now: Date,
        calendar: Calendar
    ) -> [UUID] {
        let orderedRuleIDs = rules
            .filter { $0.createdAt <= now }
            .map(\.id)
            .sorted { $0.uuidString.lowercased() < $1.uuidString.lowercased() }
        guard !orderedRuleIDs.isEmpty else { return [] }

        let dayOrdinal = calendar.ordinality(of: .day, in: .era, for: now) ?? 0
        let roster = (0..<min(maximumVisibleRoutines, orderedRuleIDs.count)).map {
            orderedRuleIDs[(dayOrdinal + $0) % orderedRuleIDs.count]
        }
        let localDayKey = DailyFocusDay.key(for: now, calendar: calendar)
        let completedRoutineIDs = Set(
            completions
                .filter { $0.localDayKey == localDayKey }
                .map(\.routineID)
        )

        // ponytail: roster is re-derived, so creating or deleting a rule can change it today; persist a daily roster only if that churn proves harmful.
        return roster.filter { !completedRoutineIDs.contains($0) }
    }
}
