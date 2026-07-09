import CoreGraphics

nonisolated enum SwipeRevealSide: Equatable {
    case leading
    case trailing
}

nonisolated enum SwipeRevealState {
    static let maxOffset: CGFloat = 104
    private static let revealThreshold: CGFloat = 72

    static func offset(for translation: CGFloat) -> CGFloat {
        min(max(translation, -maxOffset), maxOffset)
    }

    static func revealedSide(for translation: CGFloat) -> SwipeRevealSide? {
        if translation >= revealThreshold { return .leading }
        if translation <= -revealThreshold { return .trailing }
        return nil
    }

    static func restingOffset(for side: SwipeRevealSide) -> CGFloat {
        switch side {
        case .leading: maxOffset
        case .trailing: -maxOffset
        }
    }
}
