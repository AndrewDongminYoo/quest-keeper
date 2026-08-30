import Foundation
import SwiftData

@Model
final class RoutineRule {
    var id: UUID
    var title: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
    }

    var snapshot: RoutineRuleSnapshot {
        RoutineRuleSnapshot(id: id, createdAt: createdAt)
    }
}

nonisolated struct RoutineRuleSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let createdAt: Date
}
