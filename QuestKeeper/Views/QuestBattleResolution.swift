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

    static func acceptedTimestamp(isResolving: Bool, now: Date) -> Date? {
        shouldAcceptCompletion(isResolving: isResolving) ? now : nil
    }

    static func heroFrame(for phase: QuestBattlePhase) -> HeroFrame {
        switch phase {
        case .idle: .idle
        case .windUp: .windUp
        case .striking, .defeated: .strike
        }
    }

    static func showsImpact(for phase: QuestBattlePhase) -> Bool {
        phase == .striking
    }

    static func showsVictory(for phase: QuestBattlePhase) -> Bool {
        phase == .defeated
    }

    static func accessibilityValue(for phase: QuestBattlePhase, locale: Locale = .current) -> String {
        switch phase {
        case .idle: ""
        case .windUp: AppStrings.resolve(AppStrings.a11yBattleWindUp, locale: locale)
        case .striking: AppStrings.resolve(AppStrings.a11yBattleStriking, locale: locale)
        case .defeated: AppStrings.resolve(AppStrings.a11yBattleDefeated, locale: locale)
        }
    }
}
