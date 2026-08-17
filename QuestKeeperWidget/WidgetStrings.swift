import Foundation

/// 위젯 번들 문자열 리소스. 키는 `<area>.<element>.<role>` 규칙을 따른다.
nonisolated enum WidgetStrings {
    /// `WidgetStrings.swift` is compiled into both the `QuestKeeperWidget` extension and
    /// `QuestKeeperTests` (so the unit suite can assert against real English/Korean catalog
    /// output — see `WidgetStringsTests`). `LocalizedStringResource`'s default bundle is
    /// `.main`, which in a QuestKeeperTests run resolves to the app (its `TEST_HOST`), not the
    /// widget extension — the app's bundle doesn't carry the widget's `Localizable.xcstrings`.
    /// Every resource below pins `bundle: .forClass(BundleToken.self)` so lookup always uses
    /// the catalog compiled alongside whichever target this file is currently running in
    /// (`bundle` is get-only on `LocalizedStringResource`, so this has to happen at
    /// construction — `resolve(_:locale:)` can't patch it in afterward).
    private final class BundleToken {}

    private static let bundle: LocalizedStringResource.BundleDescription = .forClass(BundleToken.self)

    static func resolve(_ resource: LocalizedStringResource, locale: Locale) -> String {
        var localized = resource
        localized.locale = locale
        return String(localized: localized)
    }
}

nonisolated extension WidgetStrings {
    static let statBattleLabel = LocalizedStringResource("widget.stat.battleLabel", defaultValue: "전투", bundle: bundle)
    static let statVictoryLabel = LocalizedStringResource(
        "widget.stat.victoryLabel",
        defaultValue: "승리",
        bundle: bundle
    )
    static let statGraveLabel = LocalizedStringResource("widget.stat.graveLabel", defaultValue: "묘비", bundle: bundle)
}

nonisolated extension WidgetStrings {
    static let statusStaleReminder = LocalizedStringResource(
        "widget.status.staleReminder",
        defaultValue: "앱을 열면 갱신됩니다",
        bundle: bundle
    )
    static let statusDungeonQuiet = LocalizedStringResource(
        "widget.status.dungeonQuiet",
        defaultValue: "던전이 조용합니다",
        bundle: bundle
    )
    static let statusTopPriorityQuest = LocalizedStringResource(
        "widget.status.topPriorityQuest",
        defaultValue: "오늘의 최우선 퀘스트",
        bundle: bundle
    )

    static func statusTodayQuestCount(_ count: Int) -> LocalizedStringResource {
        LocalizedStringResource("widget.status.todayQuestCount", defaultValue: "오늘의 퀘스트 \(count)", bundle: bundle)
    }
}

nonisolated extension WidgetStrings {
    static let emptyStaleTitle = LocalizedStringResource(
        "widget.empty.staleTitle",
        defaultValue: "던전 정보가 오래됐습니다",
        bundle: bundle
    )
    static let emptyNoActiveTitle = LocalizedStringResource(
        "widget.empty.noActiveTitle",
        defaultValue: "활성 퀘스트가 없습니다",
        bundle: bundle
    )
    static let emptyStaleBody = LocalizedStringResource(
        "widget.empty.staleBody",
        defaultValue: "앱을 열어 다시 동기화하세요",
        bundle: bundle
    )
    static let emptyNoActiveBody = LocalizedStringResource(
        "widget.empty.noActiveBody",
        defaultValue: "새 퀘스트를 추가해 던전을 채우세요",
        bundle: bundle
    )
}

nonisolated extension WidgetStrings {
    static let deadlineOverdue = LocalizedStringResource(
        "widget.deadline.overdue",
        defaultValue: "기한 초과",
        bundle: bundle
    )

    static func deadlineRemaining(_ interval: String) -> LocalizedStringResource {
        LocalizedStringResource("widget.deadline.remaining", defaultValue: "\(interval) 남음", bundle: bundle)
    }
}

nonisolated extension WidgetStrings {
    static let mobDeadlineLabel = LocalizedStringResource("widget.mob.deadlineLabel", defaultValue: "기한", bundle: bundle)

    static func a11yMonsterLevel(_ monsterName: String, _ level: Int) -> LocalizedStringResource {
        LocalizedStringResource("a11y.monster.level", defaultValue: "\(monsterName) 레벨 \(level)", bundle: bundle)
    }
}

nonisolated extension WidgetStrings {
    static let questActionComplete = LocalizedStringResource("quest.action.complete", defaultValue: "완료", bundle: bundle)
}

nonisolated extension WidgetStrings {
    static let placeholderQuestOne = LocalizedStringResource(
        "widget.placeholder.questOne",
        defaultValue: "물 마시기",
        bundle: bundle
    )
    static let placeholderQuestTwo = LocalizedStringResource(
        "widget.placeholder.questTwo",
        defaultValue: "푸시업 하나",
        bundle: bundle
    )
    static let configurationDescription = LocalizedStringResource(
        "widget.configuration.description",
        defaultValue: "오늘의 던전을 홈 화면에서 확인합니다.",
        bundle: bundle
    )
    /// 위젯 갤러리에 표시되는 이름. 제품명이라 두 로캘의 값이 같다.
    static let configurationDisplayName = LocalizedStringResource(
        "widget.configuration.displayName",
        defaultValue: "TODO Slayer",
        bundle: bundle
    )
}
