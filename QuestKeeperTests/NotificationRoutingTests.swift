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

    @Test("every quest outcome routes to the common detail destination")
    func everyOutcomeRoutesToDetail() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let snapshots = [
            QuestSnapshot(
                id: UUID(),
                deadline: now.addingTimeInterval(3_600),
                completedAt: nil,
                importance: .medium
            ),
            QuestSnapshot(
                id: UUID(),
                deadline: now.addingTimeInterval(-60),
                completedAt: nil,
                importance: .medium
            ),
            QuestSnapshot(
                id: UUID(),
                deadline: now.addingTimeInterval(-60),
                completedAt: now.addingTimeInterval(-120),
                importance: .medium
            ),
            QuestSnapshot(
                id: UUID(),
                deadline: now.addingTimeInterval(-2 * 86_400),
                completedAt: nil,
                importance: .medium
            ),
        ]

        #expect(snapshots.allSatisfy {
            notificationDestination(for: $0, now: now) == .detail
        })
    }
}
