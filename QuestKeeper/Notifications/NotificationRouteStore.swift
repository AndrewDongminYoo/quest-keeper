//
//  NotificationRouteStore.swift
//  QuestKeeper
//
//  Phase 3 — transient UI route state from local notification responses.
//

import Foundation
import Observation
import SwiftData

nonisolated struct ReengagementNotificationAttribution: Equatable, Sendable {
    let questID: UUID
    let actionID: UUID
}

@MainActor
@Observable
final class NotificationRouteStore {
    var pendingQuestID: UUID?
    private var readyContainerIdentity: ObjectIdentifier?
    private var pendingReengagementActionID: UUID?
    private var resolvedReengagementAttribution: ReengagementNotificationAttribution?
    private(set) var readyGeneration = 0

    nonisolated static func questIDString(from userInfo: [AnyHashable: Any]) -> String? {
        userInfo["questID"] as? String
    }

    nonisolated static func isReengagement(userInfo: [AnyHashable: Any]) -> Bool {
        userInfo["kind"] as? String == ReengagementReminderPlanner.notificationKind
    }

    func route(userInfo: [AnyHashable: Any]) {
        route(
            questIDString: Self.questIDString(from: userInfo),
            isReengagement: Self.isReengagement(userInfo: userInfo)
        )
    }

    func route(questIDString: String?) {
        route(questIDString: questIDString, isReengagement: false)
    }

    func route(questIDString: String?, isReengagement: Bool) {
        guard
            let rawQuestID = questIDString,
            let questID = UUID(uuidString: rawQuestID)
        else { return }

        pendingQuestID = questID
        pendingReengagementActionID = isReengagement ? UUID() : nil
    }

    func clear() {
        pendingQuestID = nil
        pendingReengagementActionID = nil
        resolvedReengagementAttribution = nil
    }

    func pause() {
        readyContainerIdentity = nil
    }

    func resume(for container: ModelContainer) {
        let identity = ObjectIdentifier(container)
        guard readyContainerIdentity != identity else { return }
        readyContainerIdentity = identity
        readyGeneration += 1
    }

    func isReady(for container: ModelContainer) -> Bool {
        readyContainerIdentity == ObjectIdentifier(container)
    }

    /// Consumes the pending route, if any, and resolves it against `context`. Clears the pending ID
    /// only once the quest actually resolved, so a route that arrives before its quest is visible
    /// stays queued for the next attempt instead of being silently dropped.
    func takeRoutedQuest(in context: ModelContext) -> Quest? {
        guard isReady(for: context.container), let questID = pendingQuestID else {
            return nil
        }

        let descriptor = FetchDescriptor<Quest>(
            predicate: #Predicate { $0.id == questID }
        )
        guard let quest = try? context.fetch(descriptor).first else { return nil }
        guard pendingReengagementActionID == nil || quest.snapshot.outcome(at: .now) == .pending else {
            pendingQuestID = nil
            pendingReengagementActionID = nil
            return nil
        }
        if let actionID = pendingReengagementActionID {
            resolvedReengagementAttribution = ReengagementNotificationAttribution(
                questID: questID,
                actionID: actionID
            )
        }
        pendingQuestID = nil
        pendingReengagementActionID = nil
        return quest
    }

    func takeReengagementAttribution() -> ReengagementNotificationAttribution? {
        defer { resolvedReengagementAttribution = nil }
        return resolvedReengagementAttribution
    }
}
