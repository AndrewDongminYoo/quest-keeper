//
//  QuestNotificationKind.swift
//  QuestKeeper
//
//  Phase 3 — deterministic local-notification identities derived from quest facts.
//

import Foundation

nonisolated enum QuestNotificationKind: String, CaseIterable, Sendable {
    case dueSoon
    case deadline

    nonisolated static let identifierPrefix = "quest."

    func identifier(for questID: UUID) -> String {
        "\(Self.identifierPrefix)\(questID.uuidString).\(rawValue)"
    }
}
