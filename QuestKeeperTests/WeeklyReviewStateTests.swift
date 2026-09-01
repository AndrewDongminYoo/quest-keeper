import Foundation
import Testing
@testable import QuestKeeper

struct WeeklyReviewStateTests {
    // Sunday-first, Asia/Seoul. `now` is Wednesday 2026-07-15 12:00 KST, so the reviewed week is
    // Sun 2026-07-05 through Sat 2026-07-11 and the week before it is 2026-06-28 through 07-04.
    static let seoul = TimeZone(identifier: "Asia/Seoul")!

    static var sundayFirst: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = seoul
        calendar.firstWeekday = 1
        return calendar
    }

    static var mondayFirst: Calendar {
        var calendar = sundayFirst
        calendar.firstWeekday = 2
        return calendar
    }

    let now = Self.date("2026-07-15T12:00:00+09:00")

    @Test("an empty week reports no victories and no active days")
    func emptyWeek() {
        let review = WeeklyReviewState.make(quests: [], now: now, calendar: Self.sundayFirst)

        #expect(review?.victories == 0)
        #expect(review?.activeDays == 0)
        #expect(review?.change == 0)
        #expect(review?.hasVictories == false)
    }

    @Test("the reviewed week is the completed week before the one containing now")
    func reviewedWeekBounds() {
        let review = WeeklyReviewState.make(quests: [], now: now, calendar: Self.sundayFirst)

        #expect(review?.weekStart == Self.date("2026-07-05T00:00:00+09:00"))
        #expect(review?.weekEnd == Self.date("2026-07-12T00:00:00+09:00"))
    }

    @Test("several victories on one day are one active day")
    func victoriesOnOneDay() {
        let quests = [
            Self.victory(at: "2026-07-07T09:00:00+09:00"),
            Self.victory(at: "2026-07-07T18:00:00+09:00"),
            Self.victory(at: "2026-07-07T23:30:00+09:00"),
        ]

        let review = WeeklyReviewState.make(quests: quests, now: now, calendar: Self.sundayFirst)

        #expect(review?.victories == 3)
        #expect(review?.activeDays == 1)
    }

    @Test("victories spread over days count each day once")
    func victoriesAcrossDays() {
        let quests = [
            Self.victory(at: "2026-07-06T09:00:00+09:00"),
            Self.victory(at: "2026-07-08T09:00:00+09:00"),
            Self.victory(at: "2026-07-08T21:00:00+09:00"),
            Self.victory(at: "2026-07-11T09:00:00+09:00"),
        ]

        let review = WeeklyReviewState.make(quests: quests, now: now, calendar: Self.sundayFirst)

        #expect(review?.victories == 4)
        #expect(review?.activeDays == 3)
    }

    @Test("a late completion is a grave and does not count")
    func lateCompletionExcluded() {
        let late = QuestSnapshot(
            id: UUID(),
            deadline: Self.date("2026-07-07T09:00:00+09:00"),
            completedAt: Self.date("2026-07-07T10:00:00+09:00"),
            importance: .medium
        )

        let review = WeeklyReviewState.make(quests: [late], now: now, calendar: Self.sundayFirst)

        #expect(review?.victories == 0)
        #expect(review?.activeDays == 0)
    }

    @Test("change compares the reviewed week against the week before it")
    func changeAgainstPriorWeek() {
        let quests = [
            Self.victory(at: "2026-07-07T09:00:00+09:00"),
            Self.victory(at: "2026-07-08T09:00:00+09:00"),
            Self.victory(at: "2026-07-09T09:00:00+09:00"),
            Self.victory(at: "2026-06-30T09:00:00+09:00"),
        ]

        let review = WeeklyReviewState.make(quests: quests, now: now, calendar: Self.sundayFirst)

        #expect(review?.victories == 3)
        #expect(review?.change == 2)
    }

    @Test("a quieter week reports a negative change")
    func negativeChange() {
        let quests = [
            Self.victory(at: "2026-07-07T09:00:00+09:00"),
            Self.victory(at: "2026-06-29T09:00:00+09:00"),
            Self.victory(at: "2026-06-30T09:00:00+09:00"),
            Self.victory(at: "2026-07-01T09:00:00+09:00"),
        ]

        let review = WeeklyReviewState.make(quests: quests, now: now, calendar: Self.sundayFirst)

        #expect(review?.victories == 1)
        #expect(review?.change == -2)
    }

    @Test("a completion on the week boundary is counted in exactly one week")
    func boundaryCompletionCountedOnce() {
        // Midnight starting Sunday 2026-07-05 is the reviewed week's first instant and the prior
        // week's end. Counting it in both would report one victory and a change of zero.
        let quests = [Self.victory(at: "2026-07-05T00:00:00+09:00")]

        let review = WeeklyReviewState.make(quests: quests, now: now, calendar: Self.sundayFirst)

        #expect(review?.victories == 1)
        #expect(review?.change == 1)
    }

    @Test("the week boundary follows the calendar's first weekday")
    func firstWeekdayMovesTheBoundary() {
        let sunday = WeeklyReviewState.make(quests: [], now: now, calendar: Self.sundayFirst)
        let monday = WeeklyReviewState.make(quests: [], now: now, calendar: Self.mondayFirst)

        #expect(sunday?.weekStart == Self.date("2026-07-05T00:00:00+09:00"))
        #expect(monday?.weekStart == Self.date("2026-07-06T00:00:00+09:00"))
    }

    @Test("the time zone decides which local day a completion belongs to")
    func timeZoneDecidesTheDay() {
        var utc = Self.sundayFirst
        utc.timeZone = TimeZone(identifier: "UTC")!
        // 23:30 KST on Tuesday is 14:30 UTC the same day, while 00:30 KST on Wednesday is still
        // Tuesday in UTC — so the two instants are two local days in Seoul and one in UTC.
        let quests = [
            Self.victory(at: "2026-07-07T23:30:00+09:00"),
            Self.victory(at: "2026-07-08T00:30:00+09:00"),
        ]

        #expect(WeeklyReviewState.make(quests: quests, now: now, calendar: Self.sundayFirst)?.activeDays == 2)
        #expect(WeeklyReviewState.make(quests: quests, now: now, calendar: utc)?.activeDays == 1)
    }

    @Test("an unacknowledged week presents the card")
    func presentsWhenNeverAcknowledged() {
        #expect(WeeklyReviewState.shouldPresent(
            now: now,
            calendar: Self.sundayFirst,
            acknowledgedWeekStart: nil,
            context: Self.presentable
        ))
    }

    @Test("acknowledging the reviewed week hides the card")
    func hidesAfterAcknowledgement() {
        let week = WeeklyReviewState.reviewedWeek(now: now, calendar: Self.sundayFirst)

        #expect(WeeklyReviewState.shouldPresent(
            now: now,
            calendar: Self.sundayFirst,
            acknowledgedWeekStart: week?.start,
            context: Self.presentable
        ) == false)
    }

    @Test("the next week presents the card again")
    func presentsAgainNextWeek() {
        let acknowledged = WeeklyReviewState.reviewedWeek(now: now, calendar: Self.sundayFirst)?.start
        let nextWeek = Self.date("2026-07-22T12:00:00+09:00")

        #expect(WeeklyReviewState.shouldPresent(
            now: nextWeek,
            calendar: Self.sundayFirst,
            acknowledgedWeekStart: acknowledged,
            context: Self.presentable
        ))
    }

    @Test("a return after several weeks reviews the week that just ended, once")
    func skippedWeeksAreNotReplayed() {
        let acknowledged = WeeklyReviewState.reviewedWeek(now: now, calendar: Self.sundayFirst)?.start
        let muchLater = Self.date("2026-08-12T12:00:00+09:00")

        #expect(WeeklyReviewState.shouldPresent(
            now: muchLater,
            calendar: Self.sundayFirst,
            acknowledgedWeekStart: acknowledged,
            context: Self.presentable
        ))

        let week = WeeklyReviewState.reviewedWeek(now: muchLater, calendar: Self.sundayFirst)
        #expect(week?.start == Self.date("2026-08-02T00:00:00+09:00"))

        // Acknowledging that one week is enough; the four skipped weeks never come back.
        #expect(WeeklyReviewState.shouldPresent(
            now: muchLater,
            calendar: Self.sundayFirst,
            acknowledgedWeekStart: week?.start,
            context: Self.presentable
        ) == false)
    }

    // Each board condition is checked on its own, because a suppression that quietly stops firing
    // is invisible: the card simply does not appear, which is also what a working suppression
    // looks like.
    @Test("every board condition silences the card on its own")
    func contextSuppressesTheCard() {
        let cases: [(String, WeeklyReviewContext)] = [
            ("a fresh installation", Self.context(hasQuestHistory: false)),
            ("the guided onboarding offer", Self.context(isOnboarding: true)),
            ("the recovery card", Self.context(isRecovering: true)),
            ("an unopenable store", Self.context(storeFailedToOpen: true)),
        ]

        for (label, context) in cases {
            #expect(
                WeeklyReviewState.shouldPresent(
                    now: now,
                    calendar: Self.sundayFirst,
                    acknowledgedWeekStart: nil,
                    context: context
                ) == false,
                "\(label) must silence the card"
            )
        }
    }

    @Test("quest history counts either the creation fact or a quest still in the store")
    func questHistoryIsTheUnionOfBothSources() {
        // Both sources are needed. A user migrated from the pre-measurement schema keeps their
        // quests with no `quest_created` events, and a user who deleted every quest keeps the fact.
        #expect(WeeklyReviewContext.hasQuestHistory(hasCreatedQuest: true, hasStoredQuests: true))
        #expect(WeeklyReviewContext.hasQuestHistory(hasCreatedQuest: true, hasStoredQuests: false))
        #expect(WeeklyReviewContext.hasQuestHistory(hasCreatedQuest: false, hasStoredQuests: true))
        #expect(
            WeeklyReviewContext.hasQuestHistory(hasCreatedQuest: false, hasStoredQuests: false) == false
        )
    }

    @Test("a board with none of those conditions shows the card")
    func presentableContextShowsTheCard() {
        #expect(Self.presentable.suppressesReview == false)
        #expect(WeeklyReviewState.shouldPresent(
            now: now,
            calendar: Self.sundayFirst,
            acknowledgedWeekStart: nil,
            context: Self.presentable
        ))
    }

    static let presentable = WeeklyReviewContext(
        hasQuestHistory: true,
        isOnboarding: false,
        isRecovering: false,
        storeFailedToOpen: false
    )

    private static func context(
        hasQuestHistory: Bool = true,
        isOnboarding: Bool = false,
        isRecovering: Bool = false,
        storeFailedToOpen: Bool = false
    ) -> WeeklyReviewContext {
        WeeklyReviewContext(
            hasQuestHistory: hasQuestHistory,
            isOnboarding: isOnboarding,
            isRecovering: isRecovering,
            storeFailedToOpen: storeFailedToOpen
        )
    }

    private static func victory(at completion: String) -> QuestSnapshot {
        let completedAt = date(completion)
        return QuestSnapshot(
            id: UUID(),
            deadline: completedAt.addingTimeInterval(3_600),
            completedAt: completedAt,
            importance: .medium
        )
    }

    private static func date(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)!
    }
}
