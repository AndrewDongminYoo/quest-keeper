import Foundation

/// 앱 타깃 문자열 리소스. 키는 `<area>.<element>.<role>` 규칙을 따른다.
nonisolated enum AppStrings {
    static func heroGender(_ gender: HeroGender) -> LocalizedStringResource {
        switch gender {
        case .male: LocalizedStringResource("hero.appearance.gender.male", defaultValue: "남성형")
        case .female: LocalizedStringResource("hero.appearance.gender.female", defaultValue: "여성형")
        }
    }

    static func heroHairColor(_ color: HeroHairColor) -> LocalizedStringResource {
        switch color {
        case .black: LocalizedStringResource("hero.appearance.hair.black", defaultValue: "검정")
        case .brown: LocalizedStringResource("hero.appearance.hair.brown", defaultValue: "갈색")
        case .blue: LocalizedStringResource("hero.appearance.hair.blue", defaultValue: "파랑")
        case .red: LocalizedStringResource("hero.appearance.hair.red", defaultValue: "빨강")
        }
    }

    static func resolve(_ resource: LocalizedStringResource, locale: Locale) -> String {
        var localized = resource
        localized.locale = locale
        return String(localized: localized)
    }
}

nonisolated extension AppStrings {
    static let countdownDueNow = LocalizedStringResource("countdown.dueNow", defaultValue: "마감 임박")

    static func countdownDays(_ days: Int) -> LocalizedStringResource {
        LocalizedStringResource("countdown.days", defaultValue: "\(days)일 남음")
    }

    static func countdownHours(_ hours: Int) -> LocalizedStringResource {
        LocalizedStringResource("countdown.hours", defaultValue: "\(hours)시간")
    }

    static func countdownHoursOnly(_ hours: Int) -> LocalizedStringResource {
        LocalizedStringResource("countdown.hoursOnly", defaultValue: "\(hours)시간 남음")
    }

    static func countdownMinutes(_ minutes: Int) -> LocalizedStringResource {
        LocalizedStringResource("countdown.minutes", defaultValue: "\(minutes)분 남음")
    }
}

nonisolated extension AppStrings {
    static let a11yBattleWindUp = LocalizedStringResource("a11y.battle.windUp", defaultValue: "공격 준비 중")
    static let a11yBattleStriking = LocalizedStringResource("a11y.battle.striking", defaultValue: "공격 중")
    static let a11yBattleDefeated = LocalizedStringResource("a11y.battle.defeated", defaultValue: "승리 처리 중")
}

nonisolated extension AppStrings {
    static let notificationDueSoonTitle = LocalizedStringResource(
        "notification.dueSoon.title",
        defaultValue: "퀘스트 마감 임박"
    )
    static let notificationDueSoonBody = LocalizedStringResource(
        "notification.dueSoon.body",
        defaultValue: "퀘스트가 곧 마감됩니다"
    )
    static let notificationDeadlineTitle = LocalizedStringResource(
        "notification.deadline.title",
        defaultValue: "퀘스트 마감"
    )
    static let notificationDeadlineBody = LocalizedStringResource(
        "notification.deadline.body",
        defaultValue: "퀘스트 마감 시간이 되었습니다"
    )
}
