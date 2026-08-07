import Foundation

nonisolated enum QuestBattlePhase: Equatable {
    case idle
    case windUp
    case striking
    case defeated
}

nonisolated enum QuestBattleResolution {
    static let strikingPhaseDelay: TimeInterval = 0.18
    static let defeatedPhaseDelay: TimeInterval = 0.42
    static let commitDelay: TimeInterval = 1.05

    static func phase(elapsed: TimeInterval) -> QuestBattlePhase {
        if elapsed < 0 { return .idle }
        if elapsed < strikingPhaseDelay { return .windUp }
        if elapsed < defeatedPhaseDelay { return .striking }
        return .defeated
    }

    static func shouldAcceptCompletion(isResolving: Bool) -> Bool {
        !isResolving
    }
}
