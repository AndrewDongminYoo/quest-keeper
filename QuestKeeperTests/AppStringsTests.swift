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
                "퀘스트를 생성했습니다. 알림은 Quest Keeper에서 권한을 허용하면 받을 수 있습니다.",
                "Quest created. You can receive notifications after allowing permission in Quest Keeper."
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
}
