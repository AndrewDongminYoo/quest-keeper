import Testing
@testable import QuestKeeper

struct ReengagementReminderSettingsTests {
    private let disabled = ReengagementReminderSettings(isEnabled: false)
    private let enabled = ReengagementReminderSettings(isEnabled: true)

    @Test("disabling applies even when its measurement did not reach the store")
    func disablingIsNeverGatedOnMeasurement() {
        #expect(disabled.canApply(over: enabled, measurementCommitted: false))
        #expect(disabled.canApply(over: enabled, measurementCommitted: true))
    }

    @Test("enabling applies only after its measurement reached the store")
    func enablingIsGatedOnMeasurement() {
        #expect(enabled.canApply(over: disabled, measurementCommitted: false) == false)
        #expect(enabled.canApply(over: disabled, measurementCommitted: true))
    }

    @Test("a change that keeps the enabled state needs no measurement")
    func unchangedEnabledStateApplies() {
        var retimed = enabled
        retimed.minuteOfDay = 9 * 60

        #expect(retimed.canApply(over: enabled, measurementCommitted: false))
        #expect(disabled.canApply(over: disabled, measurementCommitted: false))
    }
}
