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

    /// The inverse of `identifier(for:)`. Neither a UUID string nor a case's raw value contains a
    /// dot, so the three components are unambiguous. Used to rebuild a request the cap evicted when
    /// the add it made room for then failed.
    static func parse(identifier: String) -> (questID: UUID, kind: QuestNotificationKind)? {
        let components = identifier.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 3,
              components[0] + "." == identifierPrefix,
              let questID = UUID(uuidString: String(components[1])),
              let kind = QuestNotificationKind(rawValue: String(components[2])) else {
            return nil
        }
        return (questID, kind)
    }
}
