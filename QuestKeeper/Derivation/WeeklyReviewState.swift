import Foundation

/// The account of a finished week, derived at read time. See `docs/specs/026-weekly-review.md`.
///
/// `victories` and `activeDays` describe the week the card reviews; `change` compares it against the
/// week before it. `activeDays` is a count of distinct local days with a victory, never a streak, so
/// a skipped day cannot reset it.
nonisolated struct WeeklyReview: Equatable, Sendable {
    let weekStart: Date
    let weekEnd: Date
    let victories: Int
    let activeDays: Int
    let change: Int

    var hasVictories: Bool { victories > 0 }
}

/// The board conditions that can silence the card, gathered so the rule is one testable value
/// rather than a chain of guards inside the view.
nonisolated struct WeeklyReviewContext: Equatable, Sendable {
    /// A fresh installation has no week to review, and its board belongs to the onboarding offer.
    let hasQuestHistory: Bool
    /// The guided onboarding offer is showing. Its template is the treatment being measured, and
    /// this card's plain editor would let a guided-cohort user walk past it.
    let isOnboarding: Bool
    /// The recovery card owns the board after a multi-day absence.
    let isRecovering: Bool
    /// The on-disk store could not be opened, so the board is an empty ephemeral copy. Reviewing it
    /// would report a quiet week the user did not have, and acknowledging that review would write a
    /// preference that outlives the failure and silences the accurate one.
    let storeFailedToOpen: Bool

    var suppressesReview: Bool {
        !hasQuestHistory || isOnboarding || isRecovering || storeFailedToOpen
    }

    /// Quest history is the union of the append-only creation fact and the current store contents,
    /// because each alone misses a real user: the fact misses anyone migrated from the
    /// pre-measurement schema, whose quests survived with no `quest_created` events, and the store
    /// misses anyone who has since deleted every quest. This composition was wrong in both
    /// directions during review, which is why it lives here with the rest of the rule.
    static func hasQuestHistory(hasCreatedQuest: Bool, hasStoredQuests: Bool) -> Bool {
        hasCreatedQuest || hasStoredQuests
    }
}

nonisolated enum WeeklyReviewState {
    /// The week the card reviews: the completed week before the one containing `now`.
    /// `nil` when the calendar cannot resolve a week interval, which no supported calendar does.
    static func reviewedWeek(now: Date, calendar: Calendar) -> DateInterval? {
        guard let currentWeek = calendar.dateInterval(of: .weekOfYear, for: now),
              let previousWeekAnchor = calendar.date(
                  byAdding: .weekOfYear,
                  value: -1,
                  to: currentWeek.start
              ) else {
            return nil
        }
        return calendar.dateInterval(of: .weekOfYear, for: previousWeekAnchor)
    }

    /// Whether the board should show the card, given the week start the user last acknowledged.
    ///
    /// Keyed on the reviewed week rather than on `now`'s week, so a return after several weeks away
    /// shows the card once, for the week that just ended, instead of once per week that was skipped.
    static func shouldPresent(
        now: Date,
        calendar: Calendar,
        acknowledgedWeekStart: Date?,
        context: WeeklyReviewContext
    ) -> Bool {
        guard !context.suppressesReview else { return false }
        guard let week = reviewedWeek(now: now, calendar: calendar) else { return false }
        guard let acknowledgedWeekStart else { return true }
        return week.start != acknowledgedWeekStart
    }

    /// The review of the week `reviewedWeek` names, or `nil` when no week can be resolved.
    static func make(quests: [QuestSnapshot], now: Date, calendar: Calendar) -> WeeklyReview? {
        guard let week = reviewedWeek(now: now, calendar: calendar),
              let priorWeekAnchor = calendar.date(byAdding: .weekOfYear, value: -1, to: week.start),
              let priorWeek = calendar.dateInterval(of: .weekOfYear, for: priorWeekAnchor) else {
            return nil
        }

        let completions = victoryCompletions(quests: quests, now: now)
        // Half-open on purpose. `DateInterval.contains` includes its end instant, and one week's end
        // is the next week's start, so a completion landing exactly on the boundary would be counted
        // in both weeks and inflate the change figure by two.
        let thisWeek = completions.filter { $0 >= week.start && $0 < week.end }
        let previousWeek = completions.filter { $0 >= priorWeek.start && $0 < priorWeek.end }
        let activeDays = Set(thisWeek.map { calendar.startOfDay(for: $0) }).count

        return WeeklyReview(
            weekStart: week.start,
            weekEnd: week.end,
            victories: thisWeek.count,
            activeDays: activeDays,
            change: thisWeek.count - previousWeek.count
        )
    }

    /// Completion instants of quests that are victories *now* — the same predicate
    /// `HeroState.totalVictories` and the Hall of Fame use, so the three surfaces cannot disagree.
    /// A quest completed after its deadline is a grave and contributes nothing.
    private static func victoryCompletions(quests: [QuestSnapshot], now: Date) -> [Date] {
        quests.compactMap { quest in
            guard quest.outcome(at: now) == .victory else { return nil }
            return quest.completedAt
        }
    }
}
