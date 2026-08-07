import Foundation
import Testing
@testable import QuestKeeper

struct QuestBattleResolutionTests {
    @Test("battle phases progress through wind-up strike and defeat")
    func phaseBoundaries() {
        #expect(QuestBattleResolution.phase(elapsed: -0.01) == .idle)
        #expect(QuestBattleResolution.phase(elapsed: 0) == .windUp)
        #expect(QuestBattleResolution.phase(elapsed: 0.179) == .windUp)
        #expect(QuestBattleResolution.phase(elapsed: 0.18) == .striking)
        #expect(QuestBattleResolution.phase(elapsed: 0.419) == .striking)
        #expect(QuestBattleResolution.phase(elapsed: 0.42) == .defeated)
    }

    @Test("battle timing stays short and ordered")
    func battleTimingStaysShortAndOrdered() {
        #expect(QuestBattleResolution.strikingPhaseDelay == 0.18)
        #expect(QuestBattleResolution.defeatedPhaseDelay == 0.42)
        #expect(QuestBattleResolution.commitDelay == 1.05)
        #expect(QuestBattleResolution.defeatedPhaseDelay > 0)
        #expect(QuestBattleResolution.defeatedPhaseDelay < QuestBattleResolution.commitDelay)
        #expect(QuestBattleResolution.commitDelay < 1.1)
    }

    @Test("resolving rows reject duplicate completion")
    func resolvingRowsRejectDuplicateCompletion() {
        #expect(QuestBattleResolution.shouldAcceptCompletion(isResolving: false))
        #expect(!QuestBattleResolution.shouldAcceptCompletion(isResolving: true))
    }

    @Test("commit waits after defeated phase becomes visible")
    func commitWaitsAfterDefeatedPhaseBecomesVisible() {
        let visibleDefeatedDuration = QuestBattleResolution.commitDelay - QuestBattleResolution.defeatedPhaseDelay

        #expect(visibleDefeatedDuration >= 0.4)
    }
}
