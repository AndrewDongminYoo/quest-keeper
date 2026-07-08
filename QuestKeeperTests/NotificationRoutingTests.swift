//
//  NotificationRoutingTests.swift
//  QuestKeeperTests
//
//  Phase 3 — notification userInfo route parsing.
//

import Foundation
import Testing
@testable import QuestKeeper

@MainActor
struct NotificationRoutingTests {
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
