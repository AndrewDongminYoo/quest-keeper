//
//  WidgetStringsTests.swift
//  QuestKeeperTests
//
//  Task 10 fix round 1 — none of the widget target's compile/gate checks resolve and assert a
//  rendered string, so a directionally-broken English composition (Finding 1) shipped clean.
//  Covers the three interpolated/plural WidgetStrings resources.
//
//  WidgetStrings.swift has no WidgetKit/AppIntents dependency, so the project also compiles it
//  directly into QuestKeeperTests (see the "QuestKeeperWidget" exception set added to that
//  target's fileSystemSynchronizedGroups) rather than linking the whole widget extension binary —
//  `@testable import QuestKeeperWidget` compiles but fails to link, since QuestKeeperTests is
//  hosted by the QuestKeeper app, not the widget extension.
//

import Foundation
import Testing

@MainActor
struct WidgetStringsTests {
    let ko = Locale(identifier: "ko")
    let en = Locale(identifier: "en")

    @Test("widget.status.todayQuestCount uses English one/other and Korean other-only")
    func statusTodayQuestCountLocalizes() {
        #expect(WidgetStrings.resolve(WidgetStrings.statusTodayQuestCount(1), locale: en) == "1 quest today")
        #expect(WidgetStrings.resolve(WidgetStrings.statusTodayQuestCount(2), locale: en) == "2 quests today")
        #expect(WidgetStrings.resolve(WidgetStrings.statusTodayQuestCount(1), locale: ko) == "오늘의 퀘스트 1")
        #expect(WidgetStrings.resolve(WidgetStrings.statusTodayQuestCount(2), locale: ko) == "오늘의 퀘스트 2")
    }

    @Test("widget.deadline.remaining does not double-mark direction in English")
    func deadlineRemainingLocalizes() {
        #expect(WidgetStrings.resolve(WidgetStrings.deadlineRemaining("in 3 hr."), locale: en) == "in 3 hr.")
        #expect(WidgetStrings.resolve(WidgetStrings.deadlineRemaining("3시간 후"), locale: ko) == "3시간 후 남음")
    }

    @Test("a11y.monster.level interpolates the monster name and level in both locales")
    func a11yMonsterLevelLocalizes() {
        #expect(WidgetStrings.resolve(WidgetStrings.a11yMonsterLevel("Slime", 3), locale: en) == "Slime Level 3")
        #expect(WidgetStrings.resolve(WidgetStrings.a11yMonsterLevel("슬라임", 3), locale: ko) == "슬라임 레벨 3")
    }
}
