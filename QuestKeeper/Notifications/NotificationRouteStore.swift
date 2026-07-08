//
//  NotificationRouteStore.swift
//  QuestKeeper
//
//  Phase 3 — transient UI route state from local notification responses.
//

import Foundation
import Observation

@MainActor
@Observable
final class NotificationRouteStore {
    var pendingQuestID: UUID?

    nonisolated static func questIDString(from userInfo: [AnyHashable: Any]) -> String? {
        userInfo["questID"] as? String
    }

    func route(userInfo: [AnyHashable: Any]) {
        route(questIDString: Self.questIDString(from: userInfo))
    }

    func route(questIDString: String?) {
        guard
            let rawQuestID = questIDString,
            let questID = UUID(uuidString: rawQuestID)
        else { return }

        pendingQuestID = questID
    }

    func clear() {
        pendingQuestID = nil
    }
}
