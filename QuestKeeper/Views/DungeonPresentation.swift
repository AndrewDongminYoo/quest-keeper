import Foundation

nonisolated enum DungeonUrgencyTone: Equatable {
    case calm
    case warning
    case danger
}

nonisolated enum DungeonPresentation {
    static func countdownText(deadline: Date, now: Date, locale: Locale = .current) -> String {
        let remaining = deadline.timeIntervalSince(now)
        guard remaining >= 60 else {
            return AppStrings.resolve(AppStrings.countdownDueNow, locale: locale)
        }

        let minutes = Int(remaining) / 60
        if minutes >= 1440 {
            return AppStrings.resolve(AppStrings.countdownDays(minutes / 1440), locale: locale)
        }
        if minutes >= 60 {
            guard minutes % 60 != 0 else {
                return AppStrings.resolve(AppStrings.countdownHoursOnly(minutes / 60), locale: locale)
            }
            let hours = AppStrings.resolve(AppStrings.countdownHours(minutes / 60), locale: locale)
            let rest = AppStrings.resolve(AppStrings.countdownMinutes(minutes % 60), locale: locale)
            return "\(hours) \(rest)"
        }
        return AppStrings.resolve(AppStrings.countdownMinutes(minutes), locale: locale)
    }

    static func urgencyTone(deadline: Date, mobLevel: Int, now: Date) -> DungeonUrgencyTone {
        let remaining = deadline.timeIntervalSince(now)
        if remaining <= 60 * 60 || mobLevel >= 4 { return .danger }
        if remaining <= 6 * 60 * 60 || mobLevel >= 2 { return .warning }
        return .calm
    }
}
