import Foundation

nonisolated enum QuestBattlePhase: Equatable {
    case idle
    case striking
    case defeated
}

nonisolated enum QuestBattleResolution {
    static let defeatedPhaseDelay: TimeInterval = 0.34
    static let commitDelay: TimeInterval = 0.82

    static func phase(elapsed: TimeInterval) -> QuestBattlePhase {
        if elapsed < 0 { return .idle }
        if elapsed < defeatedPhaseDelay { return .striking }
        return .defeated
    }

    static func shouldAcceptCompletion(isResolving: Bool) -> Bool {
        !isResolving
    }
}
