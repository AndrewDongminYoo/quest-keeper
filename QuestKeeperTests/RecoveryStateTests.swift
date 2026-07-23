import Foundation
import Testing
@testable import QuestKeeper

struct RecoveryStateTests {
    private let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
    private let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000102")!

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    private var thursday: Date {
        calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 23,
            hour: 9
        ))!
    }

    @Test("first activation and one complete date away stay ineligible")
    func ordinaryEntryIsIneligible() {
        #expect(RecoveryState.offer(
            previousLastOpened: nil,
            now: thursday,
            calendar: calendar,
            deathsWhileAway: [],
            hasStoredQuests: true,
            dailyFocusPresentation: .recommended([firstID]),
            variant: .singleQuest
        ) == nil)
        #expect(RecoveryState.offer(
            previousLastOpened: calendar.date(byAdding: .day, value: -2, to: thursday),
            now: thursday,
            calendar: calendar,
            deathsWhileAway: [],
            hasStoredQuests: true,
            dailyFocusPresentation: .recommended([firstID]),
            variant: .singleQuest
        ) == nil)
    }

    @Test("two complete local dates away create one dated offer")
    func elapsedDatesCreateOffer() {
        let monday = calendar.date(byAdding: .day, value: -3, to: thursday)!

        #expect(RecoveryState.offer(
            previousLastOpened: monday,
            now: thursday,
            calendar: calendar,
            deathsWhileAway: [],
            hasStoredQuests: true,
            dailyFocusPresentation: .recommended([firstID]),
            variant: .singleQuest
        ) == RecoveryActivationOffer(variant: .singleQuest, localDayKey: "2026-07-23"))
    }

    @Test("two unique away-window graves qualify without the date threshold")
    func repeatedMissesCreateOffer() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: thursday)!

        #expect(RecoveryState.offer(
            previousLastOpened: yesterday,
            now: thursday,
            calendar: calendar,
            deathsWhileAway: [firstID, secondID, firstID],
            hasStoredQuests: true,
            dailyFocusPresentation: .recommended([firstID]),
            variant: .chooseToday
        ) == RecoveryActivationOffer(variant: .chooseToday, localDayKey: "2026-07-23"))
    }

    @Test("no stored quest, confirmed focus, invalid clock, and disabled variant suppress recovery")
    func existingBoundariesSuppressOffer() {
        let monday = calendar.date(byAdding: .day, value: -3, to: thursday)!
        let confirmed = DailyFocusPresentationState.confirmed(
            selectedQuestIDs: [firstID],
            completedQuestIDs: []
        )

        for input in [
            RecoveryOfferInput(
                previous: monday,
                hasQuests: false,
                focus: .recommended([firstID]),
                variant: .singleQuest
            ),
            RecoveryOfferInput(
                previous: monday,
                hasQuests: true,
                focus: confirmed,
                variant: .singleQuest
            ),
            RecoveryOfferInput(
                previous: thursday.addingTimeInterval(1),
                hasQuests: true,
                focus: .recommended([firstID]),
                variant: .singleQuest
            ),
            RecoveryOfferInput(
                previous: monday,
                hasQuests: true,
                focus: .recommended([firstID]),
                variant: nil
            ),
        ] {
            #expect(RecoveryState.offer(
                previousLastOpened: input.previous,
                now: thursday,
                calendar: calendar,
                deathsWhileAway: [],
                hasStoredQuests: input.hasQuests,
                dailyFocusPresentation: input.focus,
                variant: input.variant
            ) == nil)
        }
    }

    @Test("presentation uses current ranking, fallback, and activation day")
    func presentationDerivation() {
        let offer = RecoveryActivationOffer(
            variant: .singleQuest,
            localDayKey: "2026-07-23"
        )
        let quests = [
            QuestSnapshot(
                id: secondID,
                deadline: thursday.addingTimeInterval(600),
                completedAt: nil,
                importance: .low
            ),
            QuestSnapshot(
                id: firstID,
                deadline: thursday.addingTimeInterval(300),
                completedAt: nil,
                importance: .medium
            ),
        ]

        #expect(RecoveryState.presentation(
            offer: offer,
            quests: quests,
            dailyFocusPresentation: .recommended([firstID, secondID]),
            now: thursday,
            calendar: calendar
        ) == .singleQuest(firstID))
        #expect(RecoveryState.presentation(
            offer: RecoveryActivationOffer(
                variant: .chooseToday,
                localDayKey: "2026-07-23"
            ),
            quests: quests,
            dailyFocusPresentation: .recommended([firstID, secondID]),
            now: thursday,
            calendar: calendar
        ) == .chooseToday)
        #expect(RecoveryState.presentation(
            offer: offer,
            quests: [
                QuestSnapshot(
                    id: firstID,
                    deadline: thursday.addingTimeInterval(-1),
                    completedAt: nil,
                    importance: .medium
                ),
            ],
            dailyFocusPresentation: .empty,
            now: thursday,
            calendar: calendar
        ) == .createQuest)
    }
}

private struct RecoveryOfferInput {
    let previous: Date?
    let hasQuests: Bool
    let focus: DailyFocusPresentationState
    let variant: RecoveryLoopVariant?
}
