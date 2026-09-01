//
//  AppStringsTests.swift
//  QuestKeeperTests
//
//  Task 8 (dungeon board localization) — the UI suite is pinned to Korean, so it never
//  exercises the English side of the hand-authored catalog entries. This covers the three
//  interpolated resources added for the dungeon board views: two numeric plural shapes
//  (focus.progress, quest.remaining.count) and one mixed %@/%lld shape (a11y.monster.level).
//

import Foundation
import Testing
@testable import QuestKeeper

@MainActor
struct AppStringsTests {
    let ko = Locale(identifier: "ko")
    let en = Locale(identifier: "en")

    @Test("quest details field resolves in both locales")
    func questDetailsFieldLocalizes() {
        #expect(AppStrings.resolve(AppStrings.questFieldDetails, locale: ko) == "설명")
        #expect(AppStrings.resolve(AppStrings.questFieldDetails, locale: en) == "Description")
    }

    @Test("quest detail action and completion time fields resolve in both locales")
    func questDetailFieldsLocalize() {
        #expect(AppStrings.resolve(AppStrings.questActionEdit, locale: ko) == "편집")
        #expect(AppStrings.resolve(AppStrings.questActionEdit, locale: en) == "Edit")
        #expect(AppStrings.resolve(AppStrings.questFieldCompletedAt, locale: ko) == "완료 시각")
        #expect(AppStrings.resolve(AppStrings.questFieldCompletedAt, locale: en) == "Completed at")
    }

    @Test("notification permission recovery copy resolves in both locales")
    func notificationPermissionRecoveryLocalizes() {
        #expect(
            AppStrings.resolve(AppStrings.notificationPermissionRequestBody, locale: ko)
                == "마감 알림을 받으려면 재방문 알림 설정에서 켜세요."
        )
        #expect(
            AppStrings.resolve(AppStrings.notificationPermissionRequestBody, locale: en)
                == "Enable notifications in return reminder settings for deadline alerts."
        )
        #expect(
            AppStrings.resolve(AppStrings.notificationPermissionBannerBody, locale: ko)
                == "마감 알림을 받으려면 설정에서 TODO Slayer 알림을 켜세요."
        )
        #expect(
            AppStrings.resolve(AppStrings.notificationPermissionBannerBody, locale: en)
                == "Turn on TODO Slayer notifications in Settings to get deadline alerts."
        )
    }

    @Test("focus.progress interpolates both counts in both locales")
    func focusProgressLocalizes() {
        #expect(AppStrings.resolve(AppStrings.focusProgress(2, 3), locale: ko) == "2/3 완료")
        #expect(AppStrings.resolve(AppStrings.focusProgress(2, 3), locale: en) == "2 of 3 complete")
    }

    @Test("quest.remaining.count uses English one/other and Korean other-only")
    func questRemainingCountLocalizes() {
        #expect(AppStrings.resolve(AppStrings.questRemainingCount(1), locale: en) == "1 quest remaining")
        #expect(AppStrings.resolve(AppStrings.questRemainingCount(2), locale: en) == "2 quests remaining")
        #expect(AppStrings.resolve(AppStrings.questRemainingCount(1), locale: ko) == "나머지 퀘스트 1개")
        #expect(AppStrings.resolve(AppStrings.questRemainingCount(2), locale: ko) == "나머지 퀘스트 2개")
    }

    @Test("a11y.quest.completed reads as a state, not an imperative, in both locales")
    func a11yQuestCompletedLocalizes() {
        #expect(AppStrings.resolve(AppStrings.a11yQuestCompleted("빨래"), locale: ko) == "빨래 완료됨")
        #expect(AppStrings.resolve(AppStrings.a11yQuestCompleted("Laundry"), locale: en) == "Laundry completed")
    }

    @Test("a11y.monster.level interpolates the monster name and level in both locales")
    func a11yMonsterLevelLocalizes() {
        #expect(AppStrings.resolve(AppStrings.a11yMonsterLevel("Slime", 3), locale: en) == "Slime Level 3")
        #expect(AppStrings.resolve(AppStrings.a11yMonsterLevel("슬라임", 3), locale: ko) == "슬라임 레벨 3")
    }

    @Test("quest.escalated.marker names the cause in both locales")
    func escalatedMarkerLocalizes() {
        #expect(AppStrings.resolve(AppStrings.questEscalatedMarker, locale: ko) == "마감이 다가와 세졌어요")
        // Short on purpose: the pill lives in a 100pt trailing column, and the longer
        // "Stronger — deadline is closer" clipped to "Stronger — deadl…" at .caption2.
        #expect(AppStrings.resolve(AppStrings.questEscalatedMarker, locale: en) == "Stronger, due soon")
    }

    @Test("create quest intent strings resolve approved Korean and English copy")
    func createQuestIntentStringsLocalize() {
        let resources: [(LocalizedStringResource, String, String)] = [
            (CreateQuestIntent.title, "퀘스트 생성", "Create Quest"),
            (CreateQuestIntentDialogKind.created.resource, "퀘스트를 생성했습니다.", "Quest created."),
            (
                CreateQuestIntentDialogKind.createdNeedsNotificationPermission.resource,
                "퀘스트를 생성했습니다. 알림은 TODO Slayer에서 권한을 허용하면 받을 수 있습니다.",
                "Quest created. You can receive notifications after allowing permission in TODO Slayer."
            ),
            (
                CreateQuestIntentDialogKind.createdWithFollowUpWarning.resource,
                "퀘스트는 생성했지만 일부 후속 작업을 완료하지 못했습니다.",
                "Quest created, but some follow-up work couldn't be completed."
            ),
            (
                CreateQuestIntentDialogKind.createdWithFollowUpWarningAndNotificationPermission.resource,
                "퀘스트는 생성했지만 일부 후속 작업을 완료하지 못했고 알림 권한도 필요합니다.",
                "Quest created, but some follow-up work couldn't be completed, and notification permission is also required."
            ),
            (CreateQuestIntentError.emptyTitle.resource, "제목을 입력해주세요.", "Enter a title."),
            (
                CreateQuestIntentError.deadlineNotInFuture.resource,
                "마감은 현재 시간 이후여야 합니다.",
                "The deadline must be in the future."
            ),
            (
                CreateQuestIntentError.invalidImportance.resource,
                "중요도는 낮음, 보통, 높음 중에서 선택해주세요.",
                "Choose Low, Medium, or High for importance."
            ),
            (
                CreateQuestIntentError.persistenceFailed.resource,
                "퀘스트를 생성하지 못했습니다. 다시 시도해주세요.",
                "Couldn't create the quest. Try again."
            ),
        ]

        for (resource, korean, english) in resources {
            #expect(AppStrings.resolve(resource, locale: ko) == korean)
            #expect(AppStrings.resolve(resource, locale: en) == english)
        }
    }

    // The UI suite is pinned to Korean, so the English side of the weekly-review card is only ever
    // exercised here. The interpolated shapes matter most: a catalog value whose placeholders do
    // not match the resource's arguments renders the wrong text without failing any other gate.
    @Test("the weekly review card resolves in both locales")
    func weeklyReviewLocalizes() {
        #expect(AppStrings.resolve(AppStrings.weeklyReviewTitle, locale: ko) == "지난주 전과")
        #expect(AppStrings.resolve(AppStrings.weeklyReviewTitle, locale: en) == "Last week's record")

        #expect(AppStrings.resolve(AppStrings.weeklyReviewRange("7월 5일", "7월 11일"), locale: ko)
            == "7월 5일 ~ 7월 11일")
        #expect(AppStrings.resolve(AppStrings.weeklyReviewRange("Jul 5", "Jul 11"), locale: en)
            == "Jul 5 – Jul 11")

        #expect(AppStrings.resolve(AppStrings.weeklyReviewChangeUp(2), locale: ko) == "그 전 주보다 2회 많아요.")
        #expect(AppStrings.resolve(AppStrings.weeklyReviewChangeUp(2), locale: en) == "2 more than the week before.")
        #expect(AppStrings.resolve(AppStrings.weeklyReviewChangeDown(3), locale: ko) == "그 전 주보다 3회 적어요.")
        #expect(AppStrings.resolve(AppStrings.weeklyReviewChangeDown(3), locale: en) == "3 fewer than the week before.")
        #expect(AppStrings.resolve(AppStrings.weeklyReviewChangeSame, locale: ko) == "그 전 주와 같아요.")
        #expect(AppStrings.resolve(AppStrings.weeklyReviewChangeSame, locale: en) == "Same as the week before.")

        #expect(
            AppStrings.resolve(
                AppStrings.weeklyReviewStatsAccessibility(victories: 3, activeDays: 2),
                locale: ko
            ) == "지난주 승리 3회, 활동한 날 2일."
        )
        #expect(
            AppStrings.resolve(
                AppStrings.weeklyReviewStatsAccessibility(victories: 3, activeDays: 2),
                locale: en
            ) == "Last week: 3 victories, active on 2 days."
        )

        #expect(AppStrings.resolve(AppStrings.weeklyReviewActionPlan, locale: ko) == "이번 주 첫 퀘스트")
        #expect(AppStrings.resolve(AppStrings.weeklyReviewActionPlan, locale: en) == "Plan this week")
        #expect(AppStrings.resolve(AppStrings.weeklyReviewActionDismiss, locale: ko) == "나중에")
        #expect(AppStrings.resolve(AppStrings.weeklyReviewActionDismiss, locale: en) == "Later")
    }
}
