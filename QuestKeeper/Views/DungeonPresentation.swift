import Foundation

nonisolated enum DungeonUrgencyTone: Equatable {
    case calm
    case warning
    case danger
}

nonisolated enum DungeonPresentation {
    static func countdownText(deadline: Date, now: Date) -> String {
        let remaining = deadline.timeIntervalSince(now)
        guard remaining >= 60 else { return "마감 임박" }

        let minutes = Int(remaining) / 60
        if minutes >= 1440 { return "\(minutes / 1440)일 남음" }
        if minutes >= 60 { return "\(minutes / 60)시간 \(minutes % 60)분 남음" }
        return "\(minutes)분 남음"
    }

    static func urgencyTone(deadline: Date, mobLevel: Int, now: Date) -> DungeonUrgencyTone {
        let remaining = deadline.timeIntervalSince(now)
        if remaining <= 60 * 60 || mobLevel >= 4 { return .danger }
        if remaining <= 6 * 60 * 60 || mobLevel >= 2 { return .warning }
        return .calm
    }
}
