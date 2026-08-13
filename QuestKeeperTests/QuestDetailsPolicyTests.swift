import Testing
@testable import QuestKeeper

struct QuestDetailsPolicyTests {
    @Test("nil and whitespace-only details normalize to nil")
    func emptyDetailsBecomeNil() {
        #expect(QuestDetailsPolicy.normalized(nil) == nil)
        #expect(QuestDetailsPolicy.normalized(" \t\n\r ") == nil)
    }

    @Test("normalization trims edges, normalizes line endings, and keeps at most one blank line")
    func normalizesParagraphs() {
        let raw = "  First\r\n\r\n\r\nSecond\rThird  "
        #expect(QuestDetailsPolicy.normalized(raw) == "First\n\nSecond\nThird")
    }

    @Test("normalization preserves internal spaces")
    func preservesInternalSpaces() {
        #expect(QuestDetailsPolicy.normalized("one   two") == "one   two")
    }

    @Test("normalized details stop at 1000 characters")
    func boundsCharacters() {
        let raw = String(repeating: "a", count: QuestDetailsPolicy.maximumLength + 1)
        #expect(QuestDetailsPolicy.normalized(raw)?.count == QuestDetailsPolicy.maximumLength)
    }

    @Test("truncation cannot reintroduce trailing whitespace")
    func trimsAfterBounding() {
        let raw = String(repeating: "a", count: QuestDetailsPolicy.maximumLength - 1) + "  tail"
        #expect(QuestDetailsPolicy.normalized(raw)?.last == "a")
    }

    @Test("constrained input bounds abusive grapheme clusters")
    func boundsScalars() {
        let abusive = "a" + String(repeating: "\u{0301}", count: 10_000)
        #expect(QuestDetailsPolicy.constrainedInput(abusive).unicodeScalars.count <= QuestDetailsPolicy.maximumScalars)
    }
}
