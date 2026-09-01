import Foundation
import Testing
@testable import QuestKeeper

struct QuestDetailViewTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test("pending details can edit but cannot retry")
    func pendingCapabilities() {
        let capabilities = QuestDetailCapabilities.make(
            snapshot: snapshot(deadline: now.addingTimeInterval(3_600)),
            now: now
        )
        #expect(capabilities == QuestDetailCapabilities(
            canEdit: true,
            canRetryTomorrow: false,
            canRecordLateCompletion: false
        ))
    }

    @Test("today's visible grave offers both recovery choices but cannot edit")
    func visibleGraveCapabilities() {
        let capabilities = QuestDetailCapabilities.make(
            snapshot: snapshot(deadline: now.addingTimeInterval(-60)),
            now: now
        )
        #expect(capabilities == QuestDetailCapabilities(
            canEdit: false,
            canRetryTomorrow: true,
            canRecordLateCompletion: true
        ))
    }

    @Test("a grave whose late completion is recorded offers neither recovery choice")
    func recordedLateCompletionWithdrawsBothChoices() {
        // Retry is withdrawn on purpose, not for tidiness: `QuestActions.retryTomorrow` clears
        // `completedAt`, so offering it here would discard the fact the user just recorded.
        let deadline = now.addingTimeInterval(-60)
        let lateCompletion = snapshot(deadline: deadline, completedAt: now)

        #expect(lateCompletion.outcome(at: now) == .grave)
        #expect(lateCompletion.isVisibleDailyGrave(at: now))
        #expect(QuestDetailCapabilities.make(snapshot: lateCompletion, now: now) == .readOnly)
    }

    @Test("victories and older graves are read-only")
    func resolvedCapabilities() {
        let victory = snapshot(
            deadline: now.addingTimeInterval(-60),
            completedAt: now.addingTimeInterval(-120)
        )
        let olderGrave = snapshot(deadline: now.addingTimeInterval(-2 * 86_400))

        #expect(QuestDetailCapabilities.make(snapshot: victory, now: now) == .readOnly)
        #expect(QuestDetailCapabilities.make(snapshot: olderGrave, now: now) == .readOnly)
    }

    private func snapshot(deadline: Date, completedAt: Date? = nil) -> QuestSnapshot {
        QuestSnapshot(
            id: UUID(),
            deadline: deadline,
            completedAt: completedAt,
            importance: .medium
        )
    }
}

@MainActor
struct DailyGraveRowStyleTests {
    @Test("a recorded late completion outranks the mourning treatment")
    func recordedWinsOverMourning() {
        let recordedCaption = AppStrings.resolve(AppStrings.questGraveRecordedComplete, locale: .current)

        let recordedAndNewlyMissed = DailyGraveRow.Style.make(isCompleted: true, isNewlyMissed: true)
        let recordedOnly = DailyGraveRow.Style.make(isCompleted: true, isNewlyMissed: false)

        // The row is the only feedback that the action landed, so both must report it.
        #expect(recordedAndNewlyMissed.caption == recordedCaption)
        #expect(recordedOnly.caption == recordedCaption)
        // Colour is not the only signal.
        #expect(recordedOnly.accessibilityValue == recordedCaption)
    }

    @Test("an uncompleted grave keeps its existing two variants")
    func uncompletedVariantsAreUnchanged() {
        let mourning = DailyGraveRow.Style.make(isCompleted: false, isNewlyMissed: true)
        let rest = DailyGraveRow.Style.make(isCompleted: false, isNewlyMissed: false)

        #expect(mourning.caption == AppStrings.resolve(AppStrings.questGraveJustMissed, locale: .current))
        #expect(rest.caption == AppStrings.resolve(AppStrings.dungeonGraveTitle, locale: .current))
        #expect(rest.accessibilityValue.isEmpty)
    }
}
