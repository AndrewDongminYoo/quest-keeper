//
//  QuestNotificationPlan.swift
//  QuestKeeper
//
//  Phase 3 — sendable plan values for local notifications.
//

import Foundation

nonisolated struct QuestNotificationPlan: Sendable, Equatable {
    let identifier: String
    let questID: UUID
    let kind: QuestNotificationKind
    let fireDate: Date
    let title: String
    let body: String
}
