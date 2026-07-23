# QuestKeeper Recovery Loop Prototype Verification

> This verifies DEBUG prototype behavior with deterministic simulator fixtures.
> It is not population-level evidence and does not establish a winning recovery flow or retention uplift.

## Environment

- Simulator: iPhone 17e, iOS 26.5.
- Daily-focus gate: `-dailyFocusLoopEnabled`.
- Recovery variants: `-recoveryLoopVariant singleQuest` and `-recoveryLoopVariant chooseToday`.
- Parallel testing: disabled with one test worker and two build jobs.

## Eligibility And Activation

- Initial activation, a next-day return, exactly one complete local date away, and one away-window grave remain ineligible.
- Two complete local dates away or two unique away-window graves produce one activation offer.
- Gregorian date calculation remains deterministic across the America/Los_Angeles daylight-saving boundary.
- A current-day focus confirmation, missing stored quest, future activation timestamp, missing gate, and unsupported variant suppress recovery.
- Activation replay reads fresh quest and focus snapshots from the selected model container before advancing `lastOpened`.
- An inactive-to-active transition without a genuine background transition does not derive another offer or clear the existing activation state.
- Presentation recalculates the current pending-quest ranking and does not preserve a stale single-quest candidate.

## Prototype Flow

- `singleQuest` shows the current first recommendation and records exactly one immutable focus selection only after `이 퀘스트로 다시 시작`.
- `chooseToday` opens the existing selection surface and records nothing until the user explicitly confirms one to three quests.
- Canceling `chooseToday` returns to the recovery card.
- `지금은 괜찮아요` returns to the ordinary board and does not replay the same interval after the app becomes active without a new eligible background interval.
- The no-pending fallback opens existing guided quest creation.
- Canceling creation preserves the recovery offer.
- Saving a new quest shows the ordinary daily-focus recommendation and does not auto-confirm it.
- A focus persistence conflict keeps the recovery card visible and presents neutral recovery copy.
- Missing either DEBUG gate keeps the ordinary board unchanged.

## Accessibility And Visual Checks

- At Accessibility XXXL, UI automation finds the title, supportive description, recommended quest, primary action, and dismissal action in visual order.
- Both actions retain at least a 44-point accessibility frame at Accessibility XXXL.
- The card copy contains no missed-day count, missed-quest count, streak loss, or failure framing.
- The ordinary board remains present below the non-modal recovery card.
- The primary action uses an appearance-aware foreground color in both light and dark appearance.
- The automated accessibility-tree order is a VoiceOver-order proxy; spoken VoiceOver audio was not recorded.
- Reduced Motion is not required to reveal any recovery result, and this prototype adds no required motion-only state.

## Verification Commands

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/QuestKeeperAppTests -only-testing:QuestKeeperTests/RecoveryStateTests -only-testing:QuestKeeperTests/QuestActionsTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperUITests/RecoveryLoopUITests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
```

## Evidence Limits

- Deterministic fixtures and developer review establish implementation behavior only.
- No installation assignment, recovery event, recovery report, or population cohort exists for this prototype.
- Existing retention, onboarding experiment, and daily-focus report formulas remain unchanged.
- A production decision requires a separate rollout specification with a stable evidence source, exposure boundary, observation windows, and isolation from the AND-35 population observation window.
