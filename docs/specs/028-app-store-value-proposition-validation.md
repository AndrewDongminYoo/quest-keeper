# App Store Value Proposition Validation

Tracked as Linear AND-41.
This document defines the first Korean App Store message test for TODO Slayer.
The evidence snapshot is dated 2026-09-14.

## Decision

Use a recovery-first message for the Korean App Store working draft.
The target user feels burdened by overdue tasks and wants a low-pressure way to start again.
The draft must show the product loop in this order:

1. Recognize the burden of overdue work.
2. Show the immediate reward for completing one task.
3. Promise a shame-free path after a missed deadline.

This decision selects a message to validate.
It does not establish that the message improves conversion.
Do not change the live App Store listing until the preference test and rendered-asset review in this document pass.

## Evidence Boundary

The supplied App Store Connect CSV covers 2026-06-15 through 2026-09-12.
It contains 38 product page views across 90 days and 20 product page views in the latest 30-day period.
The operator reported two downloads, but the matching date, storefront, source, and app-version filters are not verified.
The download evidence is therefore `[PARTIAL]`.

Product page views cannot establish App Store conversion by themselves.
Apple defines conversion rate from total downloads and unique impressions.
Apple also withholds product page optimization analytics until a test receives at least five first-time downloads.
The current traffic is too small to use a product page optimization test as the first message-selection tool.

Before this implementation, the Korean subtitle was `할 일을 사냥하는 픽셀 RPG 투두`.
The prior first three screenshots showed the dungeon, battle, and hero appearance without marketing captions.
Those assets demonstrated the interface, but the first sequence did not explain the recovery promise.

The Korean description already supports each selected claim:

- Today's tasks become dungeon monsters.
- A task completed before its deadline produces a one-hit victory.
- A missed task can move to tomorrow instead of becoming a permanent punishment.

## Message Candidates

The operator reviewed the three concepts as visual cards on 2026-09-14 and selected candidate A.

| Candidate         | Subtitle                              | First screenshot                               | Second screenshot                   | Third screenshot                     | Result                                                                                                                             |
| ----------------- | ------------------------------------- | ---------------------------------------------- | ----------------------------------- | ------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------- |
| A: Recovery first | `죄책감 없이 다시 시작하는 픽셀 투두` | `밀린 할 일이 부담될 땐` / `오늘의 몬스터부터` | `끝낸 할 일은` / `단칼에 처치`      | `놓쳐도 괜찮아요` / `내일 다시 도전` | Selected because it identifies the target problem, demonstrates the game reward, and ends with the product's recovery difference.  |
| B: Game first     | `할 일을 사냥하는 픽셀 RPG 투두`      | `할 일을` / `몬스터로 바꾸세요`                | `마감이 다가오면` / `몬스터가 성장` | `완료하면` / `한 번에 처치`          | Deferred because it explains the mechanic but does not distinguish TODO Slayer from another gamified task app.                     |
| C: Privacy first  | `광고 없이 기기에서 쓰는 로컬 투두`   | `계정 없이` / `바로 시작`                      | `광고 없이` / `내 일에 집중`        | `기록은` / `기기 안에만`             | Deferred because privacy reduces purchase risk but does not lead with the user's overdue-task problem or the app's primary reward. |

Candidate A is the only approved working direction.
Candidate B remains supporting language in the description.
Candidate C remains a trust statement in the feature list.

## Selected Korean Copy

### Subtitle

`죄책감 없이 다시 시작하는 픽셀 투두`

The draft contains 20 Unicode characters and remains below the documented 30-character subtitle limit.
App Store Connect must still validate the value before publication.

### First Three Screenshots

1. Dungeon
   - Support line: `밀린 할 일이 부담될 땐`
   - Headline: `오늘의 몬스터부터`
2. Battle
   - Support line: `끝낸 할 일은`
   - Headline: `단칼에 처치`
3. Daily grave
   - Support line: `놓쳐도 괜찮아요`
   - Headline: `내일 다시 도전`

The first three store assets must use the dungeon, battle, and daily-grave captures in that order.
Hero appearance moves after the first three assets.
Quest editor and empty dungeon remain supporting screenshots.

## Store Asset Scope

The screenshot test remains the source of truthful product states.
Do not add marketing text to a DEBUG-only app fixture or hand-edit a generated PNG.

The implemented composition step has these properties:

- Preserve the raw Snapshot captures as separate source artifacts.
- Generate a final 1320 by 2868 pixel App Store image from each selected source capture.
- Reserve a high-contrast caption band above an inset app capture.
- Keep the app capture uncropped so the marketing asset does not hide product state.
- Read Korean copy from one reviewable source file instead of duplicating strings in a script.
- Give output files explicit numeric prefixes that define App Store order.
- Make the existing screenshot validator inspect the final upload directory.
- Make the release lane upload only the validated final directory.

This implementation slice changes the Korean subtitle and Korean screenshot set only.
It must preserve the current English metadata and screenshots.
English recovery-first copy requires a separate native-language review before adoption.

The implementation must not change app behavior, onboarding, task rules, privacy behavior, or in-app purchase surfaces.
It must not add a design dependency when Xcode or an existing repository tool can produce the required composition.

## Preference Test

Recruit five Korean-speaking participants who use a task, habit, focus, or self-care app at least weekly.
At least three participants must have experienced an overdue or abandoned task list in the previous month.
Do not recruit only developers or existing TODO Slayer users.

For each participant:

1. Randomize candidates A, B, and C.
2. Show each three-screenshot card for five seconds before discussion.
3. Ask what the app does.
4. Ask who the app is for.
5. Ask which card makes them most likely to install the app.
6. Record the reason in the participant's words.

Do not reveal the operator's selected candidate before the participant responds.
Do not ask whether the participant likes the design as the primary question.

Candidate A passes when all conditions are true:

- At least three participants select candidate A.
- At least three participants independently describe starting again after overdue tasks or a similar recovery benefit.
- At least four participants correctly identify that completing a task defeats a monster.
- No more than one participant interprets the copy as an automatic task-selection or task-completion feature.

If candidate A fails, revise the copy once from the recorded misunderstanding and repeat the test with five new participants.
If the second test fails, keep the current live listing and return AND-41 to message discovery.

## Rendered-Asset Review

The preference card is not final visual evidence.
Before a live listing change:

1. Generate the three Korean assets at the final App Store dimensions.
2. Inspect each asset at full size for clipping, scaling artifacts, and hidden interface state.
3. Inspect a three-image contact sheet at 25 percent scale for message hierarchy and legibility.
4. Compare every rendered caption with the approved literals in this document.
5. Confirm that the daily-grave capture shows the state described by `내일 다시 도전`.

The text-source check must first fail against a deliberately changed expected literal.
Only then can its pass count as evidence that the validator reads the approved source.
Static validation cannot establish legibility or semantic accuracy.
The operator must approve the final rendered contact sheet before publication.

## Measurement After Publication

Use one App Store campaign link for each outreach source.
Record its source name, start date, end date, unique impressions, product page views, first-time downloads, and App Store Connect filters.
Do not calculate conversion from product page views.

Do not start an App Store product page optimization test until available traffic can produce at least five first-time downloads for the test.
The first acquisition experiment and the first message experiment must not change at the same time.
Otherwise, the result cannot distinguish a traffic-source effect from a store-message effect.

## Current Result

The recovery-first direction, Korean copy, local subtitle source, and generated Korean assets are implemented.
Repeated local composition produced an identical SHA-256 manifest.
Pixel comparison found zero changed pixels between each generated English screenshot and its prior committed version.
The game-first and privacy-first candidates are deferred for the reasons in this document.
The live App Store subtitle and screenshots remain unchanged.

AND-41 remains in progress until the five-person preference test and rendered-asset review pass.
Publication remains separate follow-up work.

## Sources

- `docs/store/app-store-listing.md`
- `docs/specs/016-store-release-automation.md`
- `fastlane/metadata/ko/subtitle.txt`
- `fastlane/metadata/ko/description.txt`
- `fastlane/metadata/en-US/subtitle.txt`
- `fastlane/screenshots/generated/ko/`
- `QuestKeeperUITests/StoreScreenshotUITests.swift`
- [Apple acquisition metrics](https://developer.apple.com/help/app-store-connect-analytics/acquisition/acquisition)
- [Apple product page optimization overview](https://developer.apple.com/help/app-store-connect/create-product-page-optimization-tests/overview-of-product-page-optimization)
- [Apple campaign links](https://developer.apple.com/help/app-store-connect-analytics/acquisition/campaign-links)
