//
//  DerivationTests.swift
//  QuestKeeperTests
//
//  Phase 1 — derivation layer. All inputs are hand-built QuestSnapshot values with a
//  fixed reference clock; no ModelContainer needed. See docs/specs/002-data-model-derivation.md.
//

import Testing
import Foundation
@testable import QuestKeeper

struct DerivationTests {
    /// Fixed reference clock so every test is deterministic.
    let now = Date(timeIntervalSinceReferenceDate: 700_000_000)
    let day: TimeInterval = 24 * 60 * 60

    /// Build a snapshot with offsets (in seconds) relative to `now`.
    func snapshot(
        id: UUID = UUID(),
        deadlineOffset: TimeInterval,
        completedOffset: TimeInterval? = nil,
        importance: Importance = .medium
    ) -> QuestSnapshot {
        QuestSnapshot(
            id: id,
            deadline: now.addingTimeInterval(deadlineOffset),
            completedAt: completedOffset.map { now.addingTimeInterval($0) },
            importance: importance
        )
    }

    // 1
    @Test("hero state is deterministic in its inputs")
    func determinism() {
        let quests = [
            snapshot(deadlineOffset: -day),                             // grave
            snapshot(deadlineOffset: -2 * day, completedOffset: -3 * day), // victory
            snapshot(deadlineOffset: day),                             // pending
        ]
        let lastOpened = now.addingTimeInterval(-10 * day)
        let a = HeroDerivation.state(quests: quests, now: now, lastOpened: lastOpened)
        let b = HeroDerivation.state(quests: quests, now: now, lastOpened: lastOpened)
        #expect(a == b)
    }

    // 2
    @Test("state reconstructs from facts alone after a long absence")
    func sixMonthsLaterReconstruction() {
        let sixMonths = 182 * day
        let quests = [
            snapshot(deadlineOffset: -sixMonths),                                    // grave
            snapshot(deadlineOffset: -sixMonths, completedOffset: -sixMonths - day), // victory (done before deadline)
            snapshot(deadlineOffset: -sixMonths + day, completedOffset: -sixMonths + 2 * day), // late → grave
        ]
        let state = HeroDerivation.state(quests: quests, now: now, lastOpened: now.addingTimeInterval(-sixMonths - 10 * day))
        #expect(state.victories == 1)
        #expect(state.graves == 2)
    }

    // 3
    @Test("outcome classification: pending / victory / grave / late-grave")
    func outcomeClassification() {
        #expect(snapshot(deadlineOffset: day).outcome(at: now) == .pending)
        #expect(snapshot(deadlineOffset: -day).outcome(at: now) == .grave)
        #expect(snapshot(deadlineOffset: day, completedOffset: -day).outcome(at: now) == .victory)
        #expect(snapshot(deadlineOffset: -2 * day, completedOffset: -day).outcome(at: now) == .grave)
    }

    // 4
    @Test("graves are permanent and undeletable; pending/victory are deletable")
    func gravesUndeletable() {
        let grave = snapshot(deadlineOffset: -day)
        #expect(grave.outcome(at: now) == .grave)
        #expect(grave.isDeletable(at: now) == false)

        let lateCompletion = snapshot(deadlineOffset: -2 * day, completedOffset: -day)
        #expect(lateCompletion.outcome(at: now) == .grave)   // never flips to victory
        #expect(lateCompletion.isDeletable(at: now) == false)

        #expect(snapshot(deadlineOffset: day).isDeletable(at: now) == true)                 // pending
        #expect(snapshot(deadlineOffset: day, completedOffset: -day).isDeletable(at: now))  // victory
    }

    // 5
    @Test("urgency rises while pending and is zero once a grave")
    func urgencyMonotonic() {
        let deadline = now.addingTimeInterval(8 * day)
        let q = QuestSnapshot(id: UUID(), deadline: deadline, completedAt: nil, importance: .medium)

        let uFar = q.urgency(at: deadline.addingTimeInterval(-8 * day))  // beyond horizon
        let uMid = q.urgency(at: deadline.addingTimeInterval(-3 * day))
        let uAlmost = q.urgency(at: deadline.addingTimeInterval(-60))
        let uAt = q.urgency(at: deadline)
        let uAfter = q.urgency(at: deadline.addingTimeInterval(day))     // grave

        #expect(uFar == 0)
        #expect(uMid > uFar)
        #expect(uAlmost > uMid)
        #expect(uAlmost < 1)
        #expect(uAt == 1)
        #expect(uAfter == 0)
    }

    // 6
    @Test("mob level rises with urgency and respects importance")
    func mobLevelRises() {
        let deadline = now.addingTimeInterval(6 * day)
        let low = QuestSnapshot(id: UUID(), deadline: deadline, completedAt: nil, importance: .low)
        let high = QuestSnapshot(id: UUID(), deadline: deadline, completedAt: nil, importance: .high)

        let early = deadline.addingTimeInterval(-6 * day)
        let late = deadline.addingTimeInterval(-1 * day)

        #expect(high.mobLevel(at: late) >= high.mobLevel(at: early))
        #expect(high.mobLevel(at: late) >= low.mobLevel(at: late))
    }

    // 7
    @Test("victories count on-time completions only")
    func victoriesCount() {
        let quests = [
            snapshot(deadlineOffset: day, completedOffset: -day),      // victory
            snapshot(deadlineOffset: 2 * day),                         // pending
            snapshot(deadlineOffset: -day),                            // grave
            snapshot(deadlineOffset: -2 * day, completedOffset: -day), // late → grave
        ]
        let state = HeroDerivation.state(quests: quests, now: now, lastOpened: now.addingTimeInterval(-10 * day))
        #expect(state.victories == 1)
        #expect(state.graves == 2)
    }

    // 8
    @Test("deathsWhileAway lists only graves whose deadline fell in the away window")
    func deathsWhileAway() {
        let lastOpened = now.addingTimeInterval(-5 * day)
        let diedAway = UUID()
        let diedBefore = UUID()
        let survived = UUID()
        let quests = [
            QuestSnapshot(id: diedAway, deadline: now.addingTimeInterval(-2 * day), completedAt: nil, importance: .medium),
            QuestSnapshot(id: diedBefore, deadline: now.addingTimeInterval(-10 * day), completedAt: nil, importance: .medium),
            QuestSnapshot(id: survived, deadline: now.addingTimeInterval(-2 * day), completedAt: now.addingTimeInterval(-3 * day), importance: .medium),
        ]
        let state = HeroDerivation.state(quests: quests, now: now, lastOpened: lastOpened)
        #expect(state.deathsWhileAway == [diedAway])
    }
}
