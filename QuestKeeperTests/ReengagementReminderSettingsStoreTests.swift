import Foundation
import Testing
@testable import QuestKeeper

@MainActor
struct ReengagementReminderSettingsStoreTests {
    @Test("settings store round-trips one complete configuration")
    func storeRoundTripsConfiguration() {
        let suiteName = "QuestKeeperTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ReengagementReminderSettingsStore(defaults: defaults)
        let expected = ReengagementReminderSettings(
            isEnabled: true,
            minuteOfDay: 9 * 60 + 15,
            frequency: .weekdays,
            quietHours: ReengagementQuietHours(startMinute: 21 * 60, endMinute: 7 * 60),
            purpose: .reviewPlan
        )

        store.save(expected)

        #expect(store.load() == expected)
    }

    @Test("an ephemeral store keeps a save inside its own instance")
    func ephemeralStoreDoesNotOutliveItsInstance() {
        let store = ReengagementReminderSettingsStore.ephemeral()
        let enabled = ReengagementReminderSettings(isEnabled: true)

        store.save(enabled)

        // 같은 실행 안에서는 읽힌다.
        #expect(store.load() == enabled)
        // 다른 인스턴스는 아무것도 보지 못한다. 저장이 프로세스 밖으로도 인스턴스 밖으로도 나가지 않으므로,
        // 스토어가 열리지 않은 실행에서 켠 알림이 복구된 다음 실행까지 살아남지 않는다.
        #expect(ReengagementReminderSettingsStore.ephemeral().load() == ReengagementReminderSettings())
        #expect(ReengagementReminderSettingsStore(defaults: UserDefaults(
            suiteName: "QuestKeeperTests.\(UUID().uuidString)"
        )).load() == ReengagementReminderSettings())
    }

    @Test("settings store falls back to disabled defaults for corrupt data")
    func storeFallsBackForCorruptData() {
        let suiteName = "QuestKeeperTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ReengagementReminderSettingsStore(defaults: defaults)
        defaults.set(Data("not-json".utf8), forKey: ReengagementReminderSettingsStore.storageKey)

        #expect(store.load() == ReengagementReminderSettings())
    }
}
