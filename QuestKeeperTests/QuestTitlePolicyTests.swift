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

    @Test func boundedRawInputKeepsInputAtTheBoundAndCutsBeyondIt() {
        let atBound = String(repeating: "a", count: QuestTitlePolicy.maximumRawScalars)

        #expect(QuestTitlePolicy.boundedRawInput(atBound) == atBound)
        #expect(QuestTitlePolicy.boundedRawInput(atBound + "b").unicodeScalars.count == QuestTitlePolicy.maximumRawScalars)
    }

    @Test func normalizedTitleBoundsOversizedRawInput() {
        // 단축어는 편집기의 실시간 상한을 거치지 않으므로 정규화가 원본 전체를 받는다.
        let oversizedWords = String(repeating: "slime ", count: 200_000)
        let abusiveCluster = "a" + String(repeating: "\u{0301}", count: 1_000_000)

        #expect(QuestTitlePolicy.normalized(oversizedWords).count == QuestTitlePolicy.maximumLength)
        #expect(QuestTitlePolicy.normalized(abusiveCluster).unicodeScalars.count <= QuestTitlePolicy.maximumScalars)
    }

    @Test func normalizedTitleDoesNotReadPastTheRawBound() {
        // 상한 밖의 텍스트는 정규화에 들어가지 않는다. 공백만 채운 원본 뒤의 제목은 버려진다.
        let padded = String(repeating: " ", count: QuestTitlePolicy.maximumRawScalars) + "boss"

        #expect(QuestTitlePolicy.normalized(padded).isEmpty)
    }

    @Test func normalizedTitlePreservesUnicodeUnderTheBound() {
        #expect(QuestTitlePolicy.normalized("  Caf\u{00E9} \u{1F409}\nboss  ") == "Caf\u{00E9} \u{1F409} boss")
    }
}
