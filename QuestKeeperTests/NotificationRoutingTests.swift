//
//  NotificationRoutingTests.swift
//  QuestKeeperTests
//
//  Phase 3 — notification userInfo route parsing.
//

import Foundation
import SwiftData
import Testing
@testable import QuestKeeper

@MainActor
struct NotificationRoutingTests {
    @Test("notification routing waits for the current container before consuming a quest")
    func routeWaitsForCurrentContainer() throws {
        let schema = Schema([Quest.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let oldContainer = try ModelContainer(for: schema, configurations: [configuration])
        let replacementContainer = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let missingContainer = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let questID = UUID()
        let deadline = Date(timeIntervalSinceReferenceDate: 800_000_000)
        oldContainer.mainContext.insert(Quest(
            id: questID,
            title: "Old quest",
            deadline: deadline,
            importance: .medium,
            details: "old"
        ))
        replacementContainer.mainContext.insert(Quest(
            id: questID,
            title: "Replacement quest",
            deadline: deadline,
            importance: .medium,
            details: "replacement"
        ))
        try oldContainer.mainContext.save()
        try replacementContainer.mainContext.save()

        let store = NotificationRouteStore()
        #expect(!store.isReady(for: oldContainer))
        #expect(store.readyGeneration == 0)

        store.resume(for: oldContainer)
        #expect(store.isReady(for: oldContainer))
        #expect(store.readyGeneration == 1)

        store.pause()
        store.route(questIDString: questID.uuidString)
        #expect(store.takeRoutedQuest(in: oldContainer.mainContext) == nil)
        #expect(store.pendingQuestID == questID)

        store.resume(for: replacementContainer)
        #expect(store.readyGeneration == 2)
        store.resume(for: replacementContainer)
        #expect(store.readyGeneration == 2)
        let replacement = store.takeRoutedQuest(in: replacementContainer.mainContext)
        #expect(replacement?.details == "replacement")
        #expect(store.pendingQuestID == nil)

        store.pause()
        store.route(questIDString: questID.uuidString)
        store.resume(for: missingContainer)
        #expect(store.takeRoutedQuest(in: missingContainer.mainContext) == nil)
        #expect(store.pendingQuestID == questID)
    }

    @Test("valid questID routes and invalid userInfo is ignored")
    func routeParser() {
        let store = NotificationRouteStore()
        let questID = UUID()

        store.route(userInfo: ["questID": questID.uuidString, "kind": QuestNotificationKind.deadline.rawValue])
        #expect(store.pendingQuestID == questID)

        store.route(userInfo: ["questID": "not-a-uuid"])
        #expect(store.pendingQuestID == questID)

        store.clear()
        #expect(store.pendingQuestID == nil)
    }

    @Test("reengagement routes retain one attribution only after the quest resolves")
    func reengagementRouteRetainsResolvedAttribution() throws {
        let schema = Schema([Quest.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let questID = UUID()
        container.mainContext.insert(Quest(
            id: questID,
            title: "Reminder target",
            deadline: Date.now.addingTimeInterval(60 * 60),
            importance: .medium,
            details: ""
        ))
        try container.mainContext.save()

        let store = NotificationRouteStore()
        store.route(userInfo: [
            "questID": questID.uuidString,
            "kind": ReengagementReminderPlanner.notificationKind,
        ])
        #expect(store.takeReengagementAttribution() == nil)

        store.resume(for: container)
        #expect(store.takeRoutedQuest(in: container.mainContext)?.id == questID)

        let attribution = store.takeReengagementAttribution()
        #expect(attribution?.questID == questID)
        #expect(attribution?.actionID != nil)
        #expect(store.takeReengagementAttribution() == nil)
    }

    @Test("backgrounding clears a resolved attribution and keeps an unresolved route")
    func pauseClearsResolvedAttributionOnly() throws {
        let schema = Schema([Quest.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let questID = UUID()
        container.mainContext.insert(Quest(
            id: questID,
            title: "Reminder target",
            deadline: Date.now.addingTimeInterval(60 * 60),
            importance: .medium,
            details: ""
        ))
        try container.mainContext.save()
        let reengagementUserInfo: [AnyHashable: Any] = [
            "questID": questID.uuidString,
            "kind": ReengagementReminderPlanner.notificationKind,
        ]

        let store = NotificationRouteStore()
        store.route(userInfo: reengagementUserInfo)
        store.resume(for: container)
        #expect(store.takeRoutedQuest(in: container.mainContext)?.id == questID)

        // 해결된 귀속은 같은 포그라운드 실행에서만 유효하므로 백그라운드에서 사라진다.
        store.pause()
        #expect(store.takeReengagementAttribution() == nil)

        // 아직 해결되지 않은 라우트는 남는다. 알림 탭과 scene phase 전환의 순서가 보장되지 않아
        // 여기서 버리면 콜드 스타트로 도착한 유효한 탭까지 삼키기 때문이다.
        store.route(userInfo: reengagementUserInfo)
        store.pause()
        store.resume(for: container)
        #expect(store.takeRoutedQuest(in: container.mainContext)?.id == questID)
        #expect(store.takeReengagementAttribution()?.questID == questID)
    }

    @Test("reengagement route falls back when its target is no longer pending")
    func reengagementRouteFallsBackForResolvedQuest() throws {
        let schema = Schema([Quest.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let questID = UUID()
        let completedAt = Date.now
        container.mainContext.insert(Quest(
            id: questID,
            title: "Completed reminder target",
            deadline: completedAt.addingTimeInterval(60 * 60),
            importance: .medium,
            completedAt: completedAt,
            details: ""
        ))
        try container.mainContext.save()

        let store = NotificationRouteStore()
        store.resume(for: container)
        store.route(userInfo: [
            "questID": questID.uuidString,
            "kind": ReengagementReminderPlanner.notificationKind,
        ])

        #expect(store.takeRoutedQuest(in: container.mainContext) == nil)
        #expect(store.pendingQuestID == nil)
        #expect(store.takeReengagementAttribution() == nil)
    }

    @Test("ordinary deadline routes do not create reengagement attribution")
    func ordinaryRouteHasNoReengagementAttribution() throws {
        let schema = Schema([Quest.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let questID = UUID()
        container.mainContext.insert(Quest(
            id: questID,
            title: "Deadline target",
            deadline: Date.now.addingTimeInterval(60 * 60),
            importance: .medium,
            details: ""
        ))
        try container.mainContext.save()

        let store = NotificationRouteStore()
        store.resume(for: container)
        store.route(userInfo: [
            "questID": questID.uuidString,
            "kind": QuestNotificationKind.deadline.rawValue,
        ])

        #expect(store.takeRoutedQuest(in: container.mainContext)?.id == questID)
        #expect(store.takeReengagementAttribution() == nil)
    }

}
