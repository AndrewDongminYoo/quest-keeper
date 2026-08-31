import Foundation

nonisolated struct ReengagementReminderPlan: Equatable, Sendable {
    let identifier: String
    let questID: UUID
    let dateComponents: DateComponents
    let repeats: Bool
    let title: String
    let body: String
}

nonisolated enum ReengagementReminderPlanner {
    static let identifierPrefix = "reengagement."
    static let notificationKind = "reengagement"

    static let allIdentifiers = ["reengagement.daily"] + (2...6).map { "reengagement.weekday.\($0)" }

    static func isReengagementNotificationIdentifier(_ identifier: String) -> Bool {
        identifier.hasPrefix(identifierPrefix)
    }

    static func plans(
        for snapshots: [QuestSnapshot],
        settings: ReengagementReminderSettings,
        now: Date,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> [ReengagementReminderPlan] {
        guard settings.scheduledRequestCount > 0,
              let target = target(from: snapshots, now: now) else {
            return []
        }

        switch settings.frequency {
        case .daily:
            return [plan(
                identifier: "reengagement.daily",
                questID: target.id,
                weekday: nil,
                settings: settings,
                calendar: calendar,
                locale: locale
            )]
        case .weekdays:
            return settings.frequency.weekdays.map { weekday in
                plan(
                    identifier: "reengagement.weekday.\(weekday)",
                    questID: target.id,
                    weekday: weekday,
                    settings: settings,
                    calendar: calendar,
                    locale: locale
                )
            }
        }
    }

    private static func target(from snapshots: [QuestSnapshot], now: Date) -> QuestSnapshot? {
        snapshots
            .filter { $0.outcome(at: now) == .pending }
            .sorted(by: isPreferred)
            .first
    }

    private static func isPreferred(_ lhs: QuestSnapshot, _ rhs: QuestSnapshot) -> Bool {
        if lhs.deadline != rhs.deadline { return lhs.deadline < rhs.deadline }
        if lhs.importance != rhs.importance { return lhs.importance.rawValue > rhs.importance.rawValue }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func plan(
        identifier: String,
        questID: UUID,
        weekday: Int?,
        settings: ReengagementReminderSettings,
        calendar: Calendar,
        locale: Locale
    ) -> ReengagementReminderPlan {
        var dateComponents = DateComponents()
        dateComponents.timeZone = calendar.timeZone
        dateComponents.hour = settings.minuteOfDay / 60
        dateComponents.minute = settings.minuteOfDay % 60
        dateComponents.weekday = weekday

        let title: LocalizedStringResource
        let body: LocalizedStringResource
        switch settings.purpose {
        case .finishOneQuest:
            title = AppStrings.reengagementFinishTitle
            body = AppStrings.reengagementFinishBody
        case .reviewPlan:
            title = AppStrings.reengagementReviewTitle
            body = AppStrings.reengagementReviewBody
        }

        return ReengagementReminderPlan(
            identifier: identifier,
            questID: questID,
            dateComponents: dateComponents,
            repeats: true,
            title: AppStrings.resolve(title, locale: locale),
            body: AppStrings.resolve(body, locale: locale)
        )
    }
}
