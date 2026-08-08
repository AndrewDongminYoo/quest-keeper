import Foundation

/// 앱 타깃 문자열 리소스.
/// 키는 점으로 구분된 의미 기반 계층 구조를 따르며, 세그먼트 개수는 고정이 아니다.
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

nonisolated extension AppStrings {
    static let commonActionCancel = LocalizedStringResource("common.action.cancel", defaultValue: "취소")

    static let selectionReissueAlertTitle = LocalizedStringResource(
        "selection.reissueAlert.title",
        defaultValue: "선택을 다시 확인해주세요"
    )
    static let selectionReissueAlertConfirmAction = LocalizedStringResource(
        "selection.reissueAlert.confirmAction",
        defaultValue: "확인"
    )
    static let selectionReissueAlertMessage = LocalizedStringResource(
        "selection.reissueAlert.message",
        defaultValue: "퀘스트 상태가 바뀌어 지금 선택을 저장하지 않았습니다."
    )

    static let questStatusCompleted = LocalizedStringResource("quest.status.completed", defaultValue: "완료")
    static let questFieldDeadline = LocalizedStringResource("quest.field.deadline", defaultValue: "마감")
}

nonisolated extension AppStrings {
    static let heroLabelFallen = LocalizedStringResource("hero.label.fallen", defaultValue: "쓰러진 용사")
    static let heroLabelDefault = LocalizedStringResource("hero.label.default", defaultValue: "용사")
    static let heroHeaderAppearanceButton = LocalizedStringResource(
        "hero.header.appearanceButton",
        defaultValue: "외형"
    )
    static let heroHeaderAppearanceButtonAccessibility = LocalizedStringResource(
        "hero.header.appearanceButtonAccessibility",
        defaultValue: "용사 외형 설정"
    )
    static let heroStatBattleLabel = LocalizedStringResource("hero.stat.battleLabel", defaultValue: "전투")
    static let heroStatVictoryLabel = LocalizedStringResource("hero.stat.victoryLabel", defaultValue: "승리")

    static let heroAppearanceGenderSection = LocalizedStringResource(
        "hero.appearance.genderSection",
        defaultValue: "성별"
    )
    static let heroAppearanceHairColorSection = LocalizedStringResource(
        "hero.appearance.hairColorSection",
        defaultValue: "머리색"
    )
    static let heroAppearanceNavigationTitle = LocalizedStringResource(
        "hero.appearance.navigationTitle",
        defaultValue: "용사 외형"
    )
    static let heroAppearanceDoneAction = LocalizedStringResource("hero.appearance.doneAction", defaultValue: "완료")
}

nonisolated extension AppStrings {
    static let battleSceneVictoryBanner = LocalizedStringResource("battle.scene.victoryBanner", defaultValue: "승리")
}

nonisolated extension AppStrings {
    static let questEditorTitleField = LocalizedStringResource("quest.editor.titleField", defaultValue: "제목")
    static let questEditorImportanceField = LocalizedStringResource(
        "quest.editor.importanceField",
        defaultValue: "중요도"
    )
    static let questEditorImportanceLow = LocalizedStringResource("quest.editor.importance.low", defaultValue: "낮음")
    static let questEditorImportanceMedium = LocalizedStringResource(
        "quest.editor.importance.medium",
        defaultValue: "보통"
    )
    static let questEditorImportanceHigh = LocalizedStringResource(
        "quest.editor.importance.high",
        defaultValue: "높음"
    )
    static let questEditorNewTitle = LocalizedStringResource("quest.editor.newTitle", defaultValue: "새 퀘스트")
    static let questEditorEditTitle = LocalizedStringResource("quest.editor.editTitle", defaultValue: "퀘스트 편집")
    static let questEditorSaveAction = LocalizedStringResource("quest.editor.saveAction", defaultValue: "저장")
    static let questEditorTooLarge = LocalizedStringResource(
        "quest.editor.tooLarge",
        defaultValue: "너무 큰 퀘스트예요"
    )
    static let questEditorChunkingGuideConfirm = LocalizedStringResource(
        "quest.editor.chunkingGuide.confirm",
        defaultValue: "작게 쪼개기"
    )
    static let questEditorChunkingGuideProceedAnyway = LocalizedStringResource(
        "quest.editor.chunkingGuide.proceedAnyway",
        defaultValue: "그래도 진행"
    )
    static let questEditorChunkingGuideMessage = LocalizedStringResource(
        "quest.editor.chunkingGuide.message",
        defaultValue: "작게 쪼개면 몹도 작아져요."
    )
}

nonisolated extension AppStrings {
    static let questResolutionSection = LocalizedStringResource("quest.resolution.section", defaultValue: "퀘스트")
    static let questResolutionStatusLabel = LocalizedStringResource(
        "quest.resolution.statusLabel",
        defaultValue: "상태"
    )
    static let questResolutionNavigationTitle = LocalizedStringResource(
        "quest.resolution.navigationTitle",
        defaultValue: "퀘스트 기록"
    )
    static let commonActionClose = LocalizedStringResource("common.action.close", defaultValue: "닫기")
    static let questResolutionStatusPending = LocalizedStringResource(
        "quest.resolution.status.pending",
        defaultValue: "진행 중"
    )
    static let questResolutionStatusGrave = LocalizedStringResource(
        "quest.resolution.status.grave",
        defaultValue: "무덤"
    )
}

nonisolated extension AppStrings {
    static let dailyFocusSelectionSelectedValue = LocalizedStringResource(
        "dailyFocus.selection.selectedValue",
        defaultValue: "선택됨"
    )
    static let dailyFocusSelectionNotSelectedValue = LocalizedStringResource(
        "dailyFocus.selection.notSelectedValue",
        defaultValue: "선택 안 됨"
    )
    static let dailyFocusSelectionHeader = LocalizedStringResource(
        "dailyFocus.selection.header",
        defaultValue: "오늘 집중할 퀘스트를 1–3개 선택하세요"
    )
    static let dailyFocusSelectionCompleteAction = LocalizedStringResource(
        "dailyFocus.selection.completeAction",
        defaultValue: "선택 완료"
    )

    static func dailyFocusSelectionFooterCount(_ count: Int) -> LocalizedStringResource {
        LocalizedStringResource("dailyFocus.selection.footerCount", defaultValue: "\(count)개 선택")
    }
}

nonisolated extension AppStrings {
    static let recoveryCardTitle = LocalizedStringResource("recovery.card.title", defaultValue: "다시 와서 반가워요")
    static let recoveryCardBody = LocalizedStringResource(
        "recovery.card.body",
        defaultValue: "쉬었다 와도 괜찮아요. 오늘\u{00A0}할\u{00A0}일부터 가볍게 시작해볼까요?"
    )
    static let recoveryCardBodyAccessibility = LocalizedStringResource(
        "recovery.card.bodyAccessibility",
        defaultValue: "쉬었다 와도 괜찮아요. 오늘 할 일부터 가볍게 시작해볼까요?"
    )
    static let recoveryCardDismiss = LocalizedStringResource("recovery.card.dismiss", defaultValue: "지금은 괜찮아요")
    static let recoveryCardPrimarySingleQuest = LocalizedStringResource(
        "recovery.card.primary.singleQuest",
        defaultValue: "이 퀘스트로 다시 시작"
    )
    static let recoveryCardPrimaryChooseToday = LocalizedStringResource(
        "recovery.card.primary.chooseToday",
        defaultValue: "오늘 다시 고르기"
    )
    static let recoveryCardPrimaryCreateQuest = LocalizedStringResource(
        "recovery.card.primary.createQuest",
        defaultValue: "작은 퀘스트 만들기"
    )
    static let recoveryCardPreviewLongTitle = LocalizedStringResource(
        "recovery.card.preview.longTitle",
        defaultValue: "천천히 다시 시작하는 아주 긴 회복 퀘스트 제목"
    )
}

#if DEBUG
nonisolated extension AppStrings {
    static let debugFixtureDailyFocusGraveTitle = LocalizedStringResource(
        "debug.fixture.dailyFocusGraveTitle",
        defaultValue: "어제의 퀘스트"
    )
    static let debugFixtureScreenshotPrepare = LocalizedStringResource(
        "debug.fixture.screenshotPrepare",
        defaultValue: "앱 스크린샷 준비하기"
    )
    static let debugFixtureScreenshotPrivacyPolicy = LocalizedStringResource(
        "debug.fixture.screenshotPrivacyPolicy",
        defaultValue: "개인정보처리방침 확인"
    )
    static let debugFixtureScreenshotLandingPage = LocalizedStringResource(
        "debug.fixture.screenshotLandingPage",
        defaultValue: "랜딩 페이지 다듬기"
    )
    static let debugFixtureScreenshotLaunchChecklist = LocalizedStringResource(
        "debug.fixture.screenshotLaunchChecklist",
        defaultValue: "앱 출시 체크리스트"
    )
    static let debugFixtureRecoveryLeftoverQuest = LocalizedStringResource(
        "debug.fixture.recoveryLeftoverQuest",
        defaultValue: "남겨둔 퀘스트"
    )
    static let debugFixtureRecoveryQuestOne = LocalizedStringResource(
        "debug.fixture.recoveryQuestOne",
        defaultValue: "회복 퀘스트 1"
    )
    static let debugFixtureRecoveryQuestTwo = LocalizedStringResource(
        "debug.fixture.recoveryQuestTwo",
        defaultValue: "회복 퀘스트 2"
    )
    static let debugFixtureRecoveryVictorySecured = LocalizedStringResource(
        "debug.fixture.recoveryVictorySecured",
        defaultValue: "지켜낸 승리"
    )
}
#endif
