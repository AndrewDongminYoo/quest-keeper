import Foundation
import Testing
@testable import QuestKeeper

struct DungeonPresentationTests {
    @Test("countdown text keeps days, hours, minutes, and past due readable")
    func countdownText() {
        let now = Date(timeIntervalSinceReferenceDate: 820_584_000)

        #expect(DungeonPresentation.countdownText(deadline: now.addingTimeInterval(2 * 24 * 60 * 60), now: now) == "2일 남음")
        #expect(DungeonPresentation.countdownText(deadline: now.addingTimeInterval(3 * 60 * 60 + 20 * 60), now: now) == "3시간 20분 남음")
        #expect(DungeonPresentation.countdownText(deadline: now.addingTimeInterval(15 * 60), now: now) == "15분 남음")
        #expect(DungeonPresentation.countdownText(deadline: now.addingTimeInterval(30), now: now) == "마감 임박")
        #expect(DungeonPresentation.countdownText(deadline: now.addingTimeInterval(-60), now: now) == "마감 임박")
    }

    @Test("urgency tone escalates by deadline pressure and mob level")
    func urgencyTone() {
        let now = Date(timeIntervalSinceReferenceDate: 820_584_000)

        #expect(DungeonPresentation.urgencyTone(deadline: now.addingTimeInterval(2 * 24 * 60 * 60), mobLevel: 1, now: now) == .calm)
        #expect(DungeonPresentation.urgencyTone(deadline: now.addingTimeInterval(5 * 60 * 60), mobLevel: 1, now: now) == .warning)
        #expect(DungeonPresentation.urgencyTone(deadline: now.addingTimeInterval(2 * 24 * 60 * 60), mobLevel: 3, now: now) == .warning)
        #expect(DungeonPresentation.urgencyTone(deadline: now.addingTimeInterval(30 * 60), mobLevel: 1, now: now) == .danger)
        #expect(DungeonPresentation.urgencyTone(deadline: now.addingTimeInterval(2 * 24 * 60 * 60), mobLevel: 5, now: now) == .danger)
    }
}
