# QuestKeeper Onboarding Experiment Verification

> This verifies implementation behavior on one simulator installation.
> It is not population-level evidence and does not establish an experiment winner.

## Revision

- Product commit: `8c9297edeca8c99a1012cbc977a66fc56bb6afa3`.
- Simulator: iPhone 17e, iOS 26.5 (23F77), `CDF2239B-B46C-4A44-A09E-ED656EF7F9EA`.
- Experiment: `and-34-first-value-v1`.

## Automated Verification

- The full `QuestKeeperTests` target passed with 151 tests in 26 suites and no failures.
- The `QuestKeeper` app scheme built successfully.
- The `QuestKeeperWidget` scheme built successfully.
- Parallel testing was disabled and the build used at most two jobs.

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,id=CDF2239B-B46C-4A44-A09E-ED656EF7F9EA' -only-testing:QuestKeeperTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
xcodebuild build -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,id=CDF2239B-B46C-4A44-A09E-ED656EF7F9EA' -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
xcodebuild build -project QuestKeeper.xcodeproj -scheme QuestKeeperWidget -destination 'platform=iOS Simulator,id=CDF2239B-B46C-4A44-A09E-ED656EF7F9EA' -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
```

## Control Flow

- A clean control installation retained the existing empty state and did not show guided onboarding copy.
- The header add action opened the existing blank editor.
- Saving `Control quest` recorded one exposure, one creation start, and one first-value event for the control cohort.
- The notification permission prompt appeared only after the quest was saved.
- Relaunch retained the control assignment and did not produce another exposure.

## Guided Flow

- A clean guided installation showed the approved first-value card instead of the ordinary empty-state card.
- `2분 전투 시작` opened an editor prefilled with `물 한 잔 마시기`, a ten-minute deadline, and low difficulty.
- Cancelling the editor returned to the guided card.
- `나중에` hid the card for the current process and recorded one deferral.
- Backgrounding and foregrounding the same process kept the card hidden.
- Terminating and relaunching the app restored the card because deferral is session-scoped.
- Saving the guided quest replaced the offer with `완료하면 첫 승리를 얻어요`, and relaunch preserved that pending-first-quest guidance.
- Relaunch retained the guided assignment and did not produce another exposure.

## Accessibility

- The guided card was exercised at Accessibility XXXL content size.
- A UI automation check found the title, explanation, primary action, manual action, and defer action in that order.
- The vertically scrolling layout made the lower actions hittable after a swipe, with no observed horizontal text clipping.
- Two independent visual reviews passed after the Korean line-break and secondary-action contrast fixes were recaptured without a pointer overlay.
- The AND-34 card introduces no countdown or custom animation.
- Reduced Motion could not be toggled through the available Simulator UI command, so an OS-level Reduced Motion run remains unverified.

## Live Report Check

- The control report contained one exposed installation, one creation start, one first value, and zero first completions.
- The guided report contained one exposed installation, one creation start, one first value, zero first completions, and one eligible deferral.
- Both reports marked data quality complete.
- Both reports kept D1 and D7 denominators at zero because the installations were not yet eligible.
- Neither report contained `Control quest` or `물 한 잔 마시기`.
- The existing retention report also recorded one first value and zero first completions without storing quest titles.

## Verification Limits

- The simulator's swipe-row completion and deletion buttons were exposed, but UI automation taps repeatedly closed the row instead of activating the button.
- Completion and deletion are therefore not claimed as manually verified in this pass.
- Unit tests cover first-quest completion state derivation, event joins, funnel calculation, deduplication, and observation-window eligibility.
- The checked-in synthetic baseline remains fixture output only.
- A real comparison requires independently assigned eligible installations observed through the closed cohort and observation-window rules in the specification.
