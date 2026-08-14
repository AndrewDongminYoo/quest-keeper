import AppIntents

struct QuestKeeperAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateQuestIntent(),
            phrases: ["Create a quest in \(.applicationName)"],
            shortTitle: LocalizedStringResource(
                "appShortcut.createQuest.shortTitle",
                defaultValue: "퀘스트 생성"
            ),
            systemImageName: "plus.square"
        )
    }
}
