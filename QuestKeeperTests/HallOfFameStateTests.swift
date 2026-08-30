import Foundation
import Testing
@testable import QuestKeeper

struct HallOfFameStateTests {
    let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test("current victories sort by newest completion and exclude other outcomes")
    func ordersCurrentVictories() {
        let olderID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let newerID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let lateID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        let graveID = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
        let pendingID = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
        let quests = [
            snapshot(id: olderID, deadlineOffset: 3_600, completedOffset: -600),
            snapshot(id: newerID, deadlineOffset: 3_600, completedOffset: -60),
            snapshot(id: lateID, deadlineOffset: -3_600, completedOffset: -60),
            snapshot(id: graveID, deadlineOffset: -60),
            snapshot(id: pendingID, deadlineOffset: 3_600),
        ]

        #expect(HallOfFameState.victoryQuestIDs(quests: quests, now: now) == [newerID, olderID])
    }

    @Test("equal completion times use UUID order")
    func sortsEqualCompletionTimesDeterministically() {
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let quests = [
            snapshot(id: secondID, deadlineOffset: 3_600, completedOffset: -60),
            snapshot(id: firstID, deadlineOffset: 3_600, completedOffset: -60),
        ]

        #expect(HallOfFameState.victoryQuestIDs(quests: quests, now: now) == [firstID, secondID])
    }

    @Test("changed facts remove a former victory")
    func removesUncompletedQuest() {
        let id = UUID()
        let victory = snapshot(id: id, deadlineOffset: 3_600, completedOffset: -60)
        let uncompleted = snapshot(id: id, deadlineOffset: 3_600)

        #expect(HallOfFameState.victoryQuestIDs(quests: [victory], now: now) == [id])
        #expect(HallOfFameState.victoryQuestIDs(quests: [uncompleted], now: now).isEmpty)
        #expect(HallOfFameState.victoryQuestIDs(quests: [], now: now).isEmpty)
    }

    private func snapshot(
        id: UUID,
        deadlineOffset: TimeInterval,
        completedOffset: TimeInterval? = nil
    ) -> QuestSnapshot {
        QuestSnapshot(
            id: id,
            deadline: now.addingTimeInterval(deadlineOffset),
            completedAt: completedOffset.map { now.addingTimeInterval($0) },
            importance: .medium
        )
    }
}
