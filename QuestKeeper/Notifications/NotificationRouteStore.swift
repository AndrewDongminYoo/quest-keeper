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
    /// Set when a foreground execution ended while the route was still unresolved. Spec 023 bounds
    /// an attribution to one such execution, so a route that outlived one no longer earns it.
    private var pendingReengagementIsStale = false
    /// Whether a foreground execution has actually begun. `resume(for:)` cannot answer this — both
    /// the scene phase and `ContentView`'s container observer call it, and that observer fires from
    /// an `onChange(initial: true)` that can run before the first `.active`.
    private var hasBegunForeground = false
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
        pendingReengagementIsStale = false
    }

    /// Called from the scene phase's `.active` branch, and only from there. It is what lets
    /// `pause()` tell an ending foreground from the initial `.background` that precedes every one.
    func beginForeground() {
        hasBegunForeground = true
    }

    func clear() {
        pendingQuestID = nil
        pendingReengagementActionID = nil
        pendingReengagementIsStale = false
        resolvedReengagementAttribution = nil
    }

    func pause() {
        readyContainerIdentity = nil
        // 스펙 023의 귀속 경계는 같은 포그라운드 실행이므로, 이미 해결된 귀속은 여기서 버린다.
        resolvedReengagementAttribution = nil

        // 아직 해결되지 않은 라우트는 남기되, 귀속만 만료시킨다. 라우트 자체를 버리면
        // `didReceive`와 scene phase 전환의 순서가 보장되지 않는 탓에 콜드 스타트로 도착한
        // 유효한 탭까지 삼킨다. 사용자가 누른 알림이 아무 일도 하지 않는 쪽이 더 나쁘다.
        //
        // 만료 조건은 실제로 시작된 포그라운드가 끝났을 때뿐이다. `onChange(initial: true)`의
        // 첫 `.background`는 어떤 `.active`보다도 먼저 오므로 여기서 아무것도 만료시키지 않는다.
        guard hasBegunForeground else { return }
        hasBegunForeground = false
        pendingReengagementIsStale = true
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
            pendingReengagementIsStale = false
            return nil
        }
        if let actionID = pendingReengagementActionID, !pendingReengagementIsStale {
            resolvedReengagementAttribution = ReengagementNotificationAttribution(
                questID: questID,
                actionID: actionID
            )
        }
        pendingQuestID = nil
        pendingReengagementActionID = nil
        pendingReengagementIsStale = false
        return quest
    }

    func takeReengagementAttribution() -> ReengagementNotificationAttribution? {
        defer { resolvedReengagementAttribution = nil }
        return resolvedReengagementAttribution
    }
}
