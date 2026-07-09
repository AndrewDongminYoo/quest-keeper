import Foundation
import Testing
@testable import QuestKeeper

struct QuestBattleResolutionTests {
    @Test("battle phases progress from idle to striking to defeated")
    func battlePhasesProgress() {
        #expect(QuestBattleResolution.phase(elapsed: -0.01) == .idle)
        #expect(QuestBattleResolution.phase(elapsed: 0) == .striking)
        #expect(QuestBattleResolution.phase(elapsed: QuestBattleResolution.defeatedPhaseDelay - 0.01) == .striking)
        #expect(QuestBattleResolution.phase(elapsed: QuestBattleResolution.defeatedPhaseDelay) == .defeated)
        #expect(QuestBattleResolution.phase(elapsed: QuestBattleResolution.commitDelay) == .defeated)
    }

    @Test("battle timing stays short and ordered")
    func battleTimingStaysShortAndOrdered() {
        #expect(QuestBattleResolution.defeatedPhaseDelay == 0.34)
        #expect(QuestBattleResolution.commitDelay == 0.82)
        #expect(QuestBattleResolution.defeatedPhaseDelay > 0)
        #expect(QuestBattleResolution.defeatedPhaseDelay < QuestBattleResolution.commitDelay)
        #expect(QuestBattleResolution.commitDelay < 1)
    }

    @Test("resolving rows reject duplicate completion")
    func resolvingRowsRejectDuplicateCompletion() {
        #expect(QuestBattleResolution.shouldAcceptCompletion(isResolving: false))
        #expect(!QuestBattleResolution.shouldAcceptCompletion(isResolving: true))
    }
}
