import Testing
@testable import QuestKeeper

struct QuestWriteFeedbackTests {
    @Test("a committed write clears a standing warning")
    func committedClears() {
        #expect(QuestWriteFeedback.showsFailureBanner(current: true, outcome: .committed) == false)
        #expect(QuestWriteFeedback.showsFailureBanner(current: false, outcome: .committed) == false)
    }

    @Test("a refused write raises the warning")
    func refusedRaises() {
        #expect(QuestWriteFeedback.showsFailureBanner(current: false, outcome: .refused))
        #expect(QuestWriteFeedback.showsFailureBanner(current: true, outcome: .refused))
    }

    @Test("a write that never happened leaves the previous answer alone")
    func nothingToWriteIsNotSuccess() {
        // This is the case that matters: `commitPendingChanges` returns `true` without saving when
        // there are no pending changes, and both recorders return `unchanged` for an idempotent
        // repeat. Reading either as a success would erase a warning about a refused write.
        #expect(QuestWriteFeedback.showsFailureBanner(current: true, outcome: .nothingToWrite))
        #expect(QuestWriteFeedback.showsFailureBanner(current: false, outcome: .nothingToWrite) == false)
    }
}
