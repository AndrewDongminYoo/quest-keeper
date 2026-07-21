import Foundation
import Testing
@testable import QuestKeeper

struct AnalyticsRecorderTests {
    @Test("recorder appends one newline-delimited JSON object per event")
    func appendsJSONLines() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let fileURL = directory.appending(path: "events.jsonl")
        let identity = AnalyticsIdentity(
            installationID: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
            salt: Data("salt".utf8)
        )
        let recorder = AnalyticsRecorder(
            fileURL: fileURL,
            identity: identity,
            platform: .ios,
            isTest: true,
            now: { Date(timeIntervalSince1970: 0) }
        )

        await recorder.startSession()
        await recorder.record(AnalyticsEvent(name: .appActivated))
        await recorder.record(AnalyticsEvent(name: .questRetried, properties: ["days_since_deadline": 2]))

        let lines = try String(contentsOf: fileURL, encoding: .utf8).split(separator: "\n")
        #expect(lines.count == 2)
        #expect(lines.allSatisfy { $0.first == "{" && $0.last == "}" })
    }

    @Test("quest keys are stable hashes and never expose the source UUID")
    func hashesQuestKeys() {
        let identity = AnalyticsIdentity(
            installationID: UUID(),
            salt: Data("fixed salt".utf8)
        )
        let questID = UUID(uuidString: "00000000-0000-0000-0000-000000000020")!

        let first = identity.questKey(for: questID)

        #expect(first == identity.questKey(for: questID))
        #expect(!first.contains(questID.uuidString))
        #expect(first.count == 64)
    }
}
