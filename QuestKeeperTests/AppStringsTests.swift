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
}
