import Testing
@testable import QuestKeeper

struct QuestTitlePolicyTests {
    @Test func normalizedTitleDoesNotExceedMaximumLength() {
        let oversizedTitle = String(repeating: "a", count: QuestTitlePolicy.maximumLength + 1)

        #expect(QuestTitlePolicy.normalized(oversizedTitle).count == QuestTitlePolicy.maximumLength)
    }

    @Test func normalizedTitleTrimsSurroundingWhitespaceAndNewlines() {
        #expect(QuestTitlePolicy.normalized(" \nDefeat the slime\n ") == "Defeat the slime")
    }

    @Test func normalizedTitleCollapsesEmbeddedNewlines() {
        let title = "a" + String(repeating: "\n", count: 118) + "b"

        #expect(QuestTitlePolicy.normalized(title) == "a b")
    }

    @Test func constrainedInputBoundsAbusiveGraphemeClusters() {
        // 결합 문자 1만 개를 붙인 단일 grapheme: `String.prefix`는 문자 1개로 세어 통과시킨다.
        let abusive = "a" + String(repeating: "\u{0301}", count: 10_000)

        let result = QuestTitlePolicy.constrainedInput(abusive)

        #expect(result.unicodeScalars.count <= QuestTitlePolicy.maximumScalars)
    }
}
