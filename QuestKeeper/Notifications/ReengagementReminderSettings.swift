import Foundation

nonisolated enum ReengagementReminderFrequency: String, Codable, CaseIterable, Sendable {
    case daily
    case weekdays

    var scheduledRequestCount: Int {
        switch self {
        case .daily: 1
        case .weekdays: 5
        }
    }

    var weekdays: [Int] {
        switch self {
        case .daily: []
        case .weekdays: [2, 3, 4, 5, 6]
        }
    }
}

nonisolated enum ReengagementReminderPurpose: String, Codable, CaseIterable, Sendable {
    case finishOneQuest
    case reviewPlan
}

nonisolated struct ReengagementQuietHours: Codable, Equatable, Sendable {
    let startMinute: Int
    let endMinute: Int

    func contains(_ minuteOfDay: Int) -> Bool {
        guard (0..<ReengagementReminderSettings.minutesPerDay).contains(minuteOfDay),
              (0..<ReengagementReminderSettings.minutesPerDay).contains(startMinute),
              (0..<ReengagementReminderSettings.minutesPerDay).contains(endMinute),
              startMinute != endMinute else {
            return false
        }
        if startMinute < endMinute {
            return minuteOfDay >= startMinute && minuteOfDay < endMinute
        }
        return minuteOfDay >= startMinute || minuteOfDay < endMinute
    }
}

nonisolated struct ReengagementReminderSettings: Codable, Equatable, Sendable {
    static let minutesPerDay = 24 * 60

    var isEnabled: Bool
    var minuteOfDay: Int
    var frequency: ReengagementReminderFrequency
    var quietHours: ReengagementQuietHours?
    var purpose: ReengagementReminderPurpose

    init(
        isEnabled: Bool = false,
        minuteOfDay: Int = 20 * 60,
        frequency: ReengagementReminderFrequency = .daily,
        quietHours: ReengagementQuietHours? = ReengagementQuietHours(startMinute: 22 * 60, endMinute: 8 * 60),
        purpose: ReengagementReminderPurpose = .finishOneQuest
    ) {
        self.isEnabled = isEnabled
        self.minuteOfDay = minuteOfDay
        self.frequency = frequency
        self.quietHours = quietHours
        self.purpose = purpose
    }

    var isScheduleValid: Bool {
        guard (0..<Self.minutesPerDay).contains(minuteOfDay) else { return false }
        return quietHours?.contains(minuteOfDay) != true
    }

    var scheduledRequestCount: Int {
        isEnabled && isScheduleValid ? frequency.scheduledRequestCount : 0
    }

    func canRequestAuthorization(hasCreatedQuest: Bool) -> Bool {
        hasCreatedQuest && isEnabled && isScheduleValid
    }
}

@MainActor
final class ReengagementReminderSettingsStore {
    static let storageKey = "reengagementReminderSettingsV1"
    static let shared = ReengagementReminderSettingsStore()

    private let defaults: UserDefaults?
    private var ephemeralSettings: ReengagementReminderSettings?

    init(defaults: UserDefaults? = .standard) {
        self.defaults = defaults
    }

    /// 스토어가 열리지 않은 fallback 실행과 UI 테스트용. 이 실행에서 바꾼 설정은 프로세스와 함께
    /// 사라진다. 그 실행의 퀘스트는 살아남지 못하는데 설정만 남으면, 스토어가 복구된 뒤
    /// 무관한 퀘스트에 알림이 예약된다.
    static func ephemeral() -> ReengagementReminderSettingsStore {
        ReengagementReminderSettingsStore(defaults: nil)
    }

    func load() -> ReengagementReminderSettings {
        guard let defaults else {
            return ephemeralSettings ?? ReengagementReminderSettings()
        }
        guard let data = defaults.data(forKey: Self.storageKey),
              let settings = try? JSONDecoder().decode(ReengagementReminderSettings.self, from: data) else {
            return ReengagementReminderSettings()
        }
        return settings
    }

    func save(_ settings: ReengagementReminderSettings) {
        guard let defaults else {
            ephemeralSettings = settings
            return
        }
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
