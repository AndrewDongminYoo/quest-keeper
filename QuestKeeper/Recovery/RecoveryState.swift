import Foundation

nonisolated enum RecoveryLoopVariant: String, Equatable, Sendable {
    case singleQuest
    case chooseToday
}

nonisolated struct RecoveryActivationOffer: Equatable, Sendable {
    let variant: RecoveryLoopVariant
    let localDayKey: String
}

nonisolated enum RecoveryCardPresentation: Equatable, Sendable {
    case singleQuest(UUID)
    case chooseToday
    case createQuest
}

nonisolated enum RecoveryState {
    static func offer(
        previousLastOpened: Date?,
        now: Date,
        calendar: Calendar,
        deathsWhileAway: [UUID],
        hasStoredQuests: Bool,
        dailyFocusPresentation: DailyFocusPresentationState,
        variant: RecoveryLoopVariant?
    ) -> RecoveryActivationOffer? {
        guard let previousLastOpened,
              previousLastOpened <= now,
              hasStoredQuests,
              let variant else {
            return nil
        }
        guard case .confirmed = dailyFocusPresentation else {
            let previousDay = calendar.startOfDay(for: previousLastOpened)
            let currentDay = calendar.startOfDay(for: now)
            let boundaries = calendar.dateComponents(
                [.day],
                from: previousDay,
                to: currentDay
            ).day ?? 0
            let completeDatesAway = max(0, boundaries - 1)
            let uniqueDeaths = Set(deathsWhileAway).count
            guard completeDatesAway >= 2 || uniqueDeaths >= 2 else { return nil }
            return RecoveryActivationOffer(
                variant: variant,
                localDayKey: DailyFocusDay.key(for: now, calendar: calendar)
            )
        }
        return nil
    }

    static func presentation(
        offer: RecoveryActivationOffer?,
        quests: [QuestSnapshot],
        dailyFocusPresentation: DailyFocusPresentationState,
        now: Date,
        calendar: Calendar
    ) -> RecoveryCardPresentation? {
        guard let offer,
              offer.localDayKey == DailyFocusDay.key(for: now, calendar: calendar) else {
            return nil
        }
        guard !quests.isEmpty else { return nil }
        guard case .confirmed = dailyFocusPresentation else {
            let pendingIDs = DailyFocusState.rankedPendingQuestIDs(
                quests: quests,
                now: now
            )
            guard let firstID = pendingIDs.first else { return .createQuest }
            switch offer.variant {
            case .singleQuest:
                return .singleQuest(firstID)
            case .chooseToday:
                return .chooseToday
            }
        }
        return nil
    }

    static func canConfirmSingleQuest(
        _ questID: UUID,
        offer: RecoveryActivationOffer?,
        quests: [QuestSnapshot],
        dailyFocusPresentation: DailyFocusPresentationState,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        presentation(
            offer: offer,
            quests: quests,
            dailyFocusPresentation: dailyFocusPresentation,
            now: now,
            calendar: calendar
        ) == .singleQuest(questID)
    }
}
