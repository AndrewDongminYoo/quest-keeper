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

    @Test("accepted completion preserves the action timestamp")
    func acceptedCompletionPreservesActionTimestamp() {
        let actionTimestamp = Date(timeIntervalSince1970: 1_234)

        #expect(QuestBattleResolution.acceptedTimestamp(isResolving: false, now: actionTimestamp) == actionTimestamp)
        #expect(QuestBattleResolution.acceptedTimestamp(isResolving: true, now: actionTimestamp) == nil)
    }

    @Test("battle phases map to deterministic visual and accessibility states")
    func deterministicPresentation() {
        #expect(QuestBattleResolution.heroFrame(for: .idle) == .idle)
        #expect(QuestBattleResolution.heroFrame(for: .windUp) == .windUp)
        #expect(QuestBattleResolution.heroFrame(for: .striking) == .strike)
        #expect(QuestBattleResolution.heroFrame(for: .defeated) == .strike)
        #expect(!QuestBattleResolution.showsImpact(for: .windUp))
        #expect(QuestBattleResolution.showsImpact(for: .striking))
        #expect(!QuestBattleResolution.showsVictory(for: .striking))
        #expect(QuestBattleResolution.showsVictory(for: .defeated))
        let ko = Locale(identifier: "ko")
        let en = Locale(identifier: "en")

        #expect(QuestBattleResolution.accessibilityValue(for: .windUp, locale: ko) == "공격 준비 중")
        #expect(QuestBattleResolution.accessibilityValue(for: .striking, locale: ko) == "공격 중")
        #expect(QuestBattleResolution.accessibilityValue(for: .defeated, locale: ko) == "승리 처리 중")

        #expect(QuestBattleResolution.accessibilityValue(for: .windUp, locale: en) == "Winding up")
        #expect(QuestBattleResolution.accessibilityValue(for: .striking, locale: en) == "Striking")
        #expect(QuestBattleResolution.accessibilityValue(for: .defeated, locale: en) == "Claiming victory")

        #expect(QuestBattleResolution.accessibilityValue(for: .idle, locale: ko).isEmpty)
        #expect(QuestBattleResolution.accessibilityValue(for: .idle, locale: en).isEmpty)
    }

    @Test("commit waits after defeated phase becomes visible")
    func commitWaitsAfterDefeatedPhaseBecomesVisible() {
        let visibleDefeatedDuration = QuestBattleResolution.commitDelay - QuestBattleResolution.defeatedPhaseDelay

        #expect(visibleDefeatedDuration >= 0.4)
    }
}
