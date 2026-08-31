import Foundation
import Testing
@testable import QuestKeeper

struct ReengagementReminderPlannerTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test("disabled settings schedule no reengagement reminder")
    func disabledSettingsScheduleNothing() {
        let plans = ReengagementReminderPlanner.plans(
            for: [snapshot(deadlineOffset: 2 * 60 * 60)],
            settings: ReengagementReminderSettings(isEnabled: false),
            now: now,
            calendar: calendar,
            locale: Locale(identifier: "en")
        )

        #expect(plans.isEmpty)
    }

    @Test("quiet hours suppress an otherwise enabled reminder")
    func quietHoursSuppressReminder() {
        let settings = ReengagementReminderSettings(
            isEnabled: true,
            minuteOfDay: 23 * 60,
            frequency: .daily,
            quietHours: ReengagementQuietHours(startMinute: 22 * 60, endMinute: 8 * 60),
            purpose: .finishOneQuest
        )

        let plans = ReengagementReminderPlanner.plans(
            for: [snapshot(deadlineOffset: 2 * 60 * 60)],
            settings: settings,
            now: now,
            calendar: calendar,
            locale: Locale(identifier: "en")
        )

        #expect(plans.isEmpty)
    }

    @Test("only a valid enabled configuration with a quest can request notification permission")
    func explicitValidSettingsGateAuthorization() {
        var settings = ReengagementReminderSettings(
            isEnabled: true,
            minuteOfDay: 20 * 60,
            frequency: .daily,
            quietHours: nil,
            purpose: .finishOneQuest
        )

        #expect(!settings.canRequestAuthorization(hasCreatedQuest: false))
        #expect(settings.canRequestAuthorization(hasCreatedQuest: true))

        settings.quietHours = ReengagementQuietHours(startMinute: 19 * 60, endMinute: 21 * 60)
        #expect(!settings.canRequestAuthorization(hasCreatedQuest: true))
    }

    @Test("daily reminders have one stable repeating identifier")
    func dailyReminderUsesStableIdentifier() {
        let questID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let settings = ReengagementReminderSettings(
            isEnabled: true,
            minuteOfDay: 20 * 60,
            frequency: .daily,
            quietHours: nil,
            purpose: .finishOneQuest
        )

        let plans = ReengagementReminderPlanner.plans(
            for: [snapshot(id: questID, deadlineOffset: 2 * 60 * 60)],
            settings: settings,
            now: now,
            calendar: calendar,
            locale: Locale(identifier: "en")
        )

        #expect(plans.map(\.identifier) == ["reengagement.daily"])
        #expect(plans.first?.questID == questID)
        #expect(plans.first?.dateComponents.hour == 20)
        #expect(plans.first?.dateComponents.minute == 0)
        #expect(plans.first?.dateComponents.weekday == nil)
        #expect(plans.first?.repeats == true)
    }

    @Test("weekday reminders have one stable identifier per weekday")
    func weekdayRemindersUseStableIdentifiers() {
        let settings = ReengagementReminderSettings(
            isEnabled: true,
            minuteOfDay: 9 * 60 + 30,
            frequency: .weekdays,
            quietHours: nil,
            purpose: .reviewPlan
        )

        let plans = ReengagementReminderPlanner.plans(
            for: [snapshot(deadlineOffset: 2 * 60 * 60)],
            settings: settings,
            now: now,
            calendar: calendar,
            locale: Locale(identifier: "en")
        )

        #expect(plans.map(\.identifier) == [
            "reengagement.weekday.2",
            "reengagement.weekday.3",
            "reengagement.weekday.4",
            "reengagement.weekday.5",
            "reengagement.weekday.6",
        ])
        #expect(plans.map { $0.dateComponents.weekday } == [2, 3, 4, 5, 6])
        #expect(plans.allSatisfy { $0.dateComponents.hour == 9 && $0.dateComponents.minute == 30 })
        #expect(plans.map(\.repeats) == Array(repeating: true, count: plans.count))
    }

    @Test("planner chooses the nearest pending quest with stable tie breaks")
    func plannerChoosesRelevantPendingQuestDeterministically() {
        let earliestID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let equalDeadlineLowID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let equalDeadlineHighID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        let settings = ReengagementReminderSettings(
            isEnabled: true,
            minuteOfDay: 20 * 60,
            frequency: .daily,
            quietHours: nil,
            purpose: .finishOneQuest
        )

        let plans = ReengagementReminderPlanner.plans(
            for: [
                snapshot(id: equalDeadlineLowID, deadlineOffset: 2 * 60 * 60, importance: .low),
                snapshot(id: equalDeadlineHighID, deadlineOffset: 2 * 60 * 60, importance: .high),
                snapshot(id: earliestID, deadlineOffset: 60 * 60, importance: .low),
                snapshot(deadlineOffset: -60 * 60, importance: .high),
                snapshot(deadlineOffset: 3 * 60 * 60, completedOffset: -60, importance: .high),
            ],
            settings: settings,
            now: now,
            calendar: calendar,
            locale: Locale(identifier: "en")
        )

        #expect(plans.map(\.questID) == [earliestID])
    }

    @Test("reengagement copy is fixed and does not expose quest content")
    func plannerKeepsQuestContentPrivate() {
        let settings = ReengagementReminderSettings(
            isEnabled: true,
            minuteOfDay: 20 * 60,
            frequency: .daily,
            quietHours: nil,
            purpose: .reviewPlan
        )

        let plans = ReengagementReminderPlanner.plans(
            for: [snapshot(deadlineOffset: 2 * 60 * 60)],
            settings: settings,
            now: now,
            calendar: calendar,
            locale: Locale(identifier: "en")
        )

        #expect(plans.map(\.body) == ["Review today's plan."])
        #expect(plans.allSatisfy { !$0.title.contains("private") && !$0.body.contains("private") })
    }

    private func snapshot(
        id: UUID = UUID(),
        deadlineOffset: TimeInterval,
        completedOffset: TimeInterval? = nil,
        importance: Importance = .medium
    ) -> QuestSnapshot {
        QuestSnapshot(
            id: id,
            deadline: now.addingTimeInterval(deadlineOffset),
            completedAt: completedOffset.map { now.addingTimeInterval($0) },
            importance: importance
        )
    }
}
