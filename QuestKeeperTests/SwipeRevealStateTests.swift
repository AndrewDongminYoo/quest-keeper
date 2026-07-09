import CoreGraphics
import Testing
@testable import QuestKeeper

struct SwipeRevealStateTests {
    @Test("horizontal drags reveal the expected quest action")
    func horizontalDragsRevealExpectedAction() {
        #expect(SwipeRevealState.revealedSide(for: 90) == .leading)
        #expect(SwipeRevealState.revealedSide(for: -90) == .trailing)
        #expect(SwipeRevealState.revealedSide(for: 30) == nil)
        #expect(SwipeRevealState.revealedSide(for: -30) == nil)
    }

    @Test("offset clamps to the action rail")
    func offsetClampsToActionRail() {
        #expect(SwipeRevealState.offset(for: 220) == SwipeRevealState.maxOffset)
        #expect(SwipeRevealState.offset(for: -220) == -SwipeRevealState.maxOffset)
        #expect(SwipeRevealState.offset(for: 44) == 44)
    }
}
