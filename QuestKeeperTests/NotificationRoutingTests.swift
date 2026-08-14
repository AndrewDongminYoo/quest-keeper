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

}
