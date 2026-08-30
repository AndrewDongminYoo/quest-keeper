import Foundation
import SwiftData

@Model
final class RoutineCompletion {
    var id: UUID
    var routineID: UUID
    var localDayKey: String
    var timeZoneIdentifier: String
    var completedAt: Date

    init(
        id: UUID = UUID(),
        routineID: UUID,
        localDayKey: String,
        timeZoneIdentifier: String,
        completedAt: Date
    ) {
        self.id = id
        self.routineID = routineID
        self.localDayKey = localDayKey
        self.timeZoneIdentifier = timeZoneIdentifier
        self.completedAt = completedAt
    }

    var snapshot: RoutineCompletionSnapshot {
        RoutineCompletionSnapshot(
            id: id,
            routineID: routineID,
            localDayKey: localDayKey,
            timeZoneIdentifier: timeZoneIdentifier,
            completedAt: completedAt
        )
    }
}

nonisolated struct RoutineCompletionSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let routineID: UUID
    let localDayKey: String
    let timeZoneIdentifier: String
    let completedAt: Date
}
