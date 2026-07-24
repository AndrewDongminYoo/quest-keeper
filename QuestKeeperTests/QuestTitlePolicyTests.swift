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
}
