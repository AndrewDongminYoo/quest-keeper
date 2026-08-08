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

nonisolated extension AppStrings {
    static let onboardingGuidedQuestTitle = LocalizedStringResource(
        "onboarding.guidedQuest.title",
        defaultValue: "물 한 잔 마시기"
    )
}

nonisolated extension AppStrings {
    static let dungeonEmptyTitle = LocalizedStringResource("dungeon.empty.title", defaultValue: "오늘의 던전이 비었습니다")
    static let dungeonEmptyBody = LocalizedStringResource("dungeon.empty.body", defaultValue: "작은 전투 하나를 추가해 시작하세요.")
    static let dungeonFirstWinTitle = LocalizedStringResource("dungeon.firstWin.title", defaultValue: "첫 승리를 시작해볼까요?")
    static let dungeonFirstWinBody = LocalizedStringResource(
        "dungeon.firstWin.body",
        defaultValue: "2분 안에 끝낼 수\u{00A0}있는 작은 전투부터 시작하세요."
    )
    static let dungeonFirstWinStart = LocalizedStringResource("dungeon.firstWin.start", defaultValue: "2분 전투 시작")
    static let dungeonFirstWinCreateOwn = LocalizedStringResource("dungeon.firstWin.createOwn", defaultValue: "직접 만들기")
    static let dungeonFirstWinLater = LocalizedStringResource("dungeon.firstWin.later", defaultValue: "나중에")
    static let dungeonFirstWinGuidance = LocalizedStringResource(
        "dungeon.firstWin.guidance",
        defaultValue: "완료하면 첫 승리를 얻어요"
    )
    static let dungeonGraveTitle = LocalizedStringResource("dungeon.grave.title", defaultValue: "오늘의 무덤")
    static let dungeonSectionTitle = LocalizedStringResource("dungeon.section.title", defaultValue: "던전")
}

nonisolated extension AppStrings {
    static let focusSectionTitle = LocalizedStringResource("focus.section.title", defaultValue: "오늘의 핵심 퀘스트")
    static let focusRecommendationBody = LocalizedStringResource(
        "focus.recommendation.body",
        defaultValue: "추천을 확인하고 오늘의 전투를 직접 선택하세요."
    )
    static let focusActionEdit = LocalizedStringResource("focus.action.edit", defaultValue: "핵심 퀘스트 수정")
    static let focusActionConfirm = LocalizedStringResource("focus.action.confirm", defaultValue: "오늘 이대로 시작")
    static let focusEmptyBody = LocalizedStringResource(
        "focus.empty.body",
        defaultValue: "선택한 퀘스트가 없습니다. 오늘의 핵심 퀘스트를 다시 골라주세요."
    )

    static func focusProgress(_ completed: Int, _ total: Int) -> LocalizedStringResource {
        LocalizedStringResource("focus.progress", defaultValue: "\(completed)/\(total) 완료")
    }
}

nonisolated extension AppStrings {
    static let questActionComplete = LocalizedStringResource("quest.action.complete", defaultValue: "완료")
    static let questActionDelete = LocalizedStringResource("quest.action.delete", defaultValue: "삭제")
    static let questActionAdd = LocalizedStringResource("quest.action.add", defaultValue: "전투 추가")
    static let questActionRetryTomorrow = LocalizedStringResource("quest.action.retryTomorrow", defaultValue: "내일 도전하기")
    static let questStateCompleted = LocalizedStringResource("quest.state.completed", defaultValue: "완료됨")
    static let questGraveJustMissed = LocalizedStringResource("quest.grave.justMissed", defaultValue: "방금 놓친 전투")

    static func questRemainingCount(_ count: Int) -> LocalizedStringResource {
        LocalizedStringResource("quest.remaining.count", defaultValue: "나머지 퀘스트 \(count)개")
    }
}

nonisolated extension AppStrings {
    static func a11yQuestComplete(_ title: String) -> LocalizedStringResource {
        LocalizedStringResource("a11y.quest.complete", defaultValue: "\(title) 완료")
    }

    static func a11yMonsterLevel(_ monsterName: String, _ level: Int) -> LocalizedStringResource {
        LocalizedStringResource("a11y.monster.level", defaultValue: "\(monsterName) 레벨 \(level)")
    }
}

nonisolated extension AppStrings {
    static let notificationPermissionBannerBody = LocalizedStringResource(
        "notification.permissionBanner.body",
        defaultValue: "마감 알림을 받으려면 설정에서 QuestKeeper 알림을 켜세요."
    )
}
