import Foundation
import Testing
@testable import QuestKeeper

struct AnalyticsEventTests {
    @Test("encoded events contain the common envelope without quest titles")
    func commonEnvelopeExcludesQuestTitle() throws {
        let event = AnalyticsEvent(
            name: .questCreated,
            properties: [
                "quest_key": "hashed-id",
                "importance": "high",
                "deadline_bucket": "today",
                "creation_source": "editor"
            ]
        )
        let envelope = AnalyticsEnvelope(
            event: event,
            context: AnalyticsContext(
                eventID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                occurredAt: Date(timeIntervalSince1970: 0),
                localDay: "1970-01-01",
                installationID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                sessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                appVersion: "1.0",
                buildNumber: "1",
                platform: .ios,
                isTest: true
            )
        )

        let data = try AnalyticsJSON.encoder.encode(envelope)
        let json = String(decoding: data, as: UTF8.self)

        #expect(json.contains("\"schema_version\":1"))
        #expect(json.contains("\"event_name\":\"quest_created\""))
        #expect(json.contains("\"quest_key\":\"hashed-id\""))
        #expect(!json.contains("title"))
    }
}
