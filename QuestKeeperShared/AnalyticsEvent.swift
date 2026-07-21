import Foundation

nonisolated enum AnalyticsEventName: String, Codable, Sendable {
    case appActivated = "app_activated"
    case questCreated = "quest_created"
    case firstValueExperienced = "first_value_experienced"
    case questCompleted = "quest_completed"
    case questRetried = "quest_retried"
    case notificationOpened = "notification_opened"
}

nonisolated enum AnalyticsValue: Codable, Equatable, Sendable,
    ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral,
    ExpressibleByBooleanLiteral {
    case string(String)
    case integer(Int)
    case double(Double)
    case boolean(Bool)

    init(stringLiteral value: String) { self = .string(value) }
    init(integerLiteral value: Int) { self = .integer(value) }
    init(floatLiteral value: Double) { self = .double(value) }
    init(booleanLiteral value: Bool) { self = .boolean(value) }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) { self = .boolean(value) }
        else if let value = try? container.decode(Int.self) { self = .integer(value) }
        else if let value = try? container.decode(Double.self) { self = .double(value) }
        else { self = .string(try container.decode(String.self)) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .boolean(let value): try container.encode(value)
        }
    }
}

nonisolated struct AnalyticsEvent: Sendable, Equatable {
    let name: AnalyticsEventName
    let properties: [String: AnalyticsValue]

    init(name: AnalyticsEventName, properties: [String: AnalyticsValue] = [:]) {
        self.name = name
        self.properties = properties
    }
}

nonisolated enum AnalyticsPlatform: String, Codable, Sendable {
    case ios
    case widget
}

nonisolated struct AnalyticsContext: Sendable {
    let eventID: UUID
    let occurredAt: Date
    let localDay: String
    let installationID: UUID
    let sessionID: UUID
    let appVersion: String
    let buildNumber: String
    let platform: AnalyticsPlatform
    let isTest: Bool
}

nonisolated struct AnalyticsEnvelope: Encodable, Sendable {
    let eventID: UUID
    let eventName: AnalyticsEventName
    let occurredAt: Date
    let localDay: String
    let installationID: UUID
    let sessionID: UUID
    let appVersion: String
    let buildNumber: String
    let platform: AnalyticsPlatform
    let schemaVersion = 1
    let isTest: Bool
    let properties: [String: AnalyticsValue]

    init(event: AnalyticsEvent, context: AnalyticsContext) {
        eventID = context.eventID
        eventName = event.name
        occurredAt = context.occurredAt
        localDay = context.localDay
        installationID = context.installationID
        sessionID = context.sessionID
        appVersion = context.appVersion
        buildNumber = context.buildNumber
        platform = context.platform
        isTest = context.isTest
        properties = event.properties
    }

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id", eventName = "event_name", occurredAt = "occurred_at"
        case localDay = "local_day", installationID = "installation_id", sessionID = "session_id"
        case appVersion = "app_version", buildNumber = "build_number", platform
        case schemaVersion = "schema_version", isTest = "is_test", properties
    }

}

nonisolated enum AnalyticsJSON {
    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}

nonisolated func analyticsDeadlineBucket(deadline: Date, now: Date, calendar: Calendar = .current) -> String {
    let start = calendar.startOfDay(for: now)
    let deadlineDay = calendar.startOfDay(for: deadline)
    let days = calendar.dateComponents([.day], from: start, to: deadlineDay).day ?? 0
    switch days {
    case ..<0: return "overdue"
    case 0: return "today"
    case 1: return "tomorrow"
    case 2...7: return "within_7d"
    default: return "later"
    }
}
