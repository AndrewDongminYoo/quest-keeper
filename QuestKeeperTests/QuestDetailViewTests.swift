import Foundation
import Testing
@testable import QuestKeeper

struct QuestDetailViewTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test("pending details can edit but cannot retry")
    func pendingCapabilities() {
        let capabilities = QuestDetailCapabilities.make(
            snapshot: snapshot(deadline: now.addingTimeInterval(3_600)),
            now: now
        )
        #expect(capabilities == QuestDetailCapabilities(canEdit: true, canRetryTomorrow: false))
    }

    @Test("today's visible grave can retry but cannot edit")
    func visibleGraveCapabilities() {
        let capabilities = QuestDetailCapabilities.make(
            snapshot: snapshot(deadline: now.addingTimeInterval(-60)),
            now: now
        )
        #expect(capabilities == QuestDetailCapabilities(canEdit: false, canRetryTomorrow: true))
    }

    @Test("victories and older graves are read-only")
    func resolvedCapabilities() {
        let victory = snapshot(
            deadline: now.addingTimeInterval(-60),
            completedAt: now.addingTimeInterval(-120)
        )
        let olderGrave = snapshot(deadline: now.addingTimeInterval(-2 * 86_400))

        #expect(QuestDetailCapabilities.make(snapshot: victory, now: now) == .readOnly)
        #expect(QuestDetailCapabilities.make(snapshot: olderGrave, now: now) == .readOnly)
    }

    private func snapshot(deadline: Date, completedAt: Date? = nil) -> QuestSnapshot {
        QuestSnapshot(
            id: UUID(),
            deadline: deadline,
            completedAt: completedAt,
            importance: .medium
        )
    }
}
