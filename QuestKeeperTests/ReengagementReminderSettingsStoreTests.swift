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
