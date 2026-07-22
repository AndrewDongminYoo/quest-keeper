# Spec 014 — Daily Focus Loop

Status: design approved; written spec pending review
Tracks: AND-35
Depends on: AND-33

## Goal

Help the user actively choose one to three quests for the current local day, keep that commitment visible until the day changes, and measure whether an explicit daily choice is associated with completion and next-day return.
Recommendations may reduce decision cost, but a recommendation is not a selection until the user confirms it.

## Product Decision

On the first entry of each local day, recommend up to three pending quests and let the user edit the recommendation.
The recommendation becomes the day's focus only when the user selects `오늘 이대로 시작`.
This explicit confirmation is the measurement boundary for daily focus selection.

Once confirmed, the selected set remains stable for the day.
Completing a focus quest updates progress but does not automatically replace it.
The user may explicitly revise the set, and every revision is stored as a new immutable snapshot rather than overwriting prior intent.

The feature remains dormant in ordinary app execution until the AND-34 observation window has closed and its D7 population is eligible.
During implementation and QA, the feature is available only in DEBUG builds through the launch argument `-dailyFocusLoopEnabled`.
Development-only usage is excluded from evidence about population-level retention.

## Scope

In scope:

- rank and recommend up to three pending quests once per local day;
- require an explicit daily confirmation before treating recommendations as a selection;
- allow editing before confirmation and explicit revision after confirmation;
- persist confirmations and revisions as immutable `DailyFocusSelection` snapshots;
- keep the latest valid snapshot stable across relaunches for the same local day;
- recompute recommendations on a later local day without carrying an unconfirmed recommendation forward;
- show focus progress without automatically replacing completed quests;
- keep non-focus pending quests available in a collapsed section after confirmation;
- preserve the existing daily-grave recovery section;
- calculate a pure local focus-selection, focus-completion, and next-day-return report;
- restore the previous SF Symbol on `내일 도전하기` buttons so the native button treatment remains visually coherent;
- verify empty, overloaded, completion, editing, deletion, relaunch, date-change, accessibility, and dormant-gate behavior.

Out of scope:

- enabling AND-35 for ordinary production execution before the AND-34 D7 observation window is complete;
- changing AND-34 assignment, events, eligibility, observation windows, or reports;
- automatic completion, automatic replacement, or automatic confirmation of a recommendation;
- streaks, punishment, permanent failure pressure, guilt-driven copy, or coercive notifications;
- remote analytics, accounts, network transmission, or person-level identity;
- server-driven recommendations, machine learning, or a generalized ranking framework;
- changing quest deadlines, importance, notification behavior, widget behavior, or grave derivation;
- adding focus properties to `Quest`;
- treating development fixtures or local reports as population-level evidence.

## Daily Identity

A focus day is a local Gregorian calendar date evaluated with an explicit calendar and time zone.
Production presentation uses the user's current calendar time zone at the time the screen is derived.
Tests and reports inject their calendar, time zone, and current time.

The current day is represented by a stable `yyyy-MM-dd` local date key and the time-zone identifier used to derive it.
If a time-zone change produces a different current local date key, the app treats it as a different focus day and computes a new recommendation.
It does not mutate or merge earlier snapshots.

Crossing local midnight while the app remains open invalidates the prior day's presentation and derives the new day's unconfirmed recommendation.
Yesterday's unfinished focus quests receive no failure state and remain ordinary pending candidates when otherwise eligible.

## Recommendation Rule

Only quests whose derived outcome is pending at the current time are recommendation candidates.
Daily graves, completed quests, and deleted quests are excluded.

Sort candidates by:

1. nearest deadline first;
2. higher importance first when deadlines are equal;
3. lexicographically ascending UUID string as the deterministic final tie-breaker.

Take the first three candidates.
If one or two candidates exist, recommend all of them.
If no candidate exists, show the existing empty state and do not offer daily confirmation.

The recommendation is derived presentation state and is never persisted before confirmation.
Relaunching before confirmation may recompute it from the current quest facts.
Creating, editing, completing, retrying, or deleting a quest before confirmation may therefore change the recommendation.

## Explicit Confirmation And Editing

Before confirmation, the existing full dungeon remains usable.
A `오늘의 핵심 퀘스트` recommendation card presents one to three preselected quests, an edit action, and the primary action `오늘 이대로 시작`.

The edit surface lists current pending quests in recommendation order and permits selecting one to three items.
The confirm action is disabled when the selection is empty or contains more than three quests.
Closing the edit surface without confirming leaves no persisted selection.

Selecting `오늘 이대로 시작` appends the first immutable snapshot for the local day.
The UI changes to the confirmed focus layout only after the snapshot is saved successfully.

After confirmation, `핵심 퀘스트 수정` opens the same one-to-three selection surface initialized from the latest effective snapshot.
Saving a changed set appends a revision snapshot.
Saving the same ordered set is a no-op and does not create a duplicate record.
Canceling a revision preserves the latest snapshot.

## Immutable `DailyFocusSelection`

Add `DailyFocusSelection` to the existing App Group SwiftData schema.
It contains only:

- `id`: the snapshot UUID;
- `schemaVersion`;
- `installationID`;
- `localDayKey` in `yyyy-MM-dd` form;
- `timeZoneIdentifier`;
- `selectedQuestIDsData`, a deterministically encoded ordered list of one to three quest UUIDs;
- `recordedAt`;
- `kindRawValue`, either `confirmation` or `revision`.

The initializer and recorder are the only supported production write path.
Production code exposes no API that mutates a stored snapshot after insertion.
`Quest` remains unchanged because focus membership is a user-selection fact, not an intrinsic quest property.

The recorder validates that quest IDs are unique, the selection contains one to three IDs, the date key and time-zone identifier are valid, and a revision follows a valid confirmation for the same installation and local day.
It canonicalizes the selected quest IDs into recommendation order before encoding so equal logical selections produce equal bytes.

For one installation and local day, the earliest valid `confirmation` is the selection boundary.
Later valid `revision` snapshots form an append-only history.
The effective UI selection is the latest valid snapshot ordered by `recordedAt`, then snapshot UUID as the deterministic tie-breaker.
Multiple confirmations, a revision before confirmation, malformed payloads, unsupported schema versions, or conflicting rows at the same deterministic position make local report quality partial.

If persistence fails, the app does not block quest use.
It keeps the existing full dungeon, shows no confirmed focus state, and excludes the failed action from focus metrics.

## Confirmed Focus Presentation

After confirmation, the main board shows:

- section title `오늘의 핵심 퀘스트`;
- progress text in `완료 수/유효 선택 수` form, such as `1/3`;
- the latest effective selection in its stored order;
- action `핵심 퀘스트 수정`;
- collapsed disclosure `나머지 퀘스트 N개` for pending quests outside the effective focus selection;
- the existing `오늘의 무덤` section as a separate recovery area.

A focus quest completed on the current day remains visible in the focus section as completed and contributes to progress.
It is not automatically replaced.
Non-focus pending quests retain the existing edit, swipe-complete, and delete behavior when the disclosure is expanded.

If a selected quest is deleted, it disappears from the effective visible set and does not count as completed.
Historical snapshots remain unchanged for measurement.
If no selected quest remains resolvable, the focus section asks the user to choose again through `핵심 퀘스트 수정`; the original confirmation still counts as an active selection fact.

Completed focus quests are excluded from `나머지 퀘스트`.
Daily graves remain excluded from both focus selection and the remaining-pending count.

## Completion And Day Change

The existing right-swipe `완료` action remains the only focus completion action.
It records the same `quest_completed` fact and preserves the existing battle feedback timing.
Focus progress is derived from the latest quest facts and current selection snapshots rather than persisted as a counter.

At local day change, the prior selection stops controlling presentation.
Pending quests from the prior focus set may be recommended again under the normal ranking rule.
There is no missed-focus state, penalty, warning, or accumulated unfinished count.

## `내일 도전하기` Icon

The `내일 도전하기` action returns to the prior SF Symbol `arrow.uturn.forward` instead of displaying the standalone `icon-retry` pixel asset on a native button.
Apply this consistently to both the quest-row recovery action and the resolution view.
The button labels, actions, colors, sizing, and notification-rescheduling behavior remain unchanged.
No new image generation or asset separation is required.

## Daily Focus Report

Add a pure `DailyFocusReport` beside, not inside, `RetentionReport` or `OnboardingExperimentReport`.
It accepts explicit focus-selection snapshots, retention-installation snapshots, retention-event snapshots, `asOf`, calendar, reporting time zone, and a half-open reporting interval.
It must not read SwiftData, global clocks, `UserDefaults`, view state, or the network.
Do not add daily-focus names to `RetentionEventName`; immutable selection snapshots define focus intent, while the existing `app_activated` and `quest_completed` facts provide revisit and completion evidence.

The report canonicalizes valid snapshots by installation and local day and calculates:

- daily focus selection rate: app-active local days with a valid explicit confirmation divided by eligible app-active local days;
- focus quest completion rate: unique quests included in any valid snapshot for a selected local day and completed after their first inclusion but before that local day ends, divided by unique quests included in any valid snapshot for that day;
- selected-day completion rate: selected local days with at least one qualifying focused-quest completion divided by selected local days;
- next-day revisit rate: eligible selected local days followed by an `app_activated` event on the immediately following local date divided by selected local days whose next-day observation window has matured;
- edit rate: selected local days with at least one valid revision divided by selected local days;
- data-quality counts for unsupported, malformed, conflicting, missing-installation, and out-of-order snapshots.

An app-active local day is a local date with at least one canonical `app_activated` event for the installation.
The selection-rate denominator includes only app-active days within the reporting interval after the feature has been deliberately enabled for ordinary execution.
Development launch-argument sessions and dates inside the protected AND-34 observation window must not be used as population evidence.

Each rate includes its numerator, eligible denominator, reporting interval, `asOf`, and reporting time zone.
An empty denominator renders no rate rather than zero percent.
The report right-censors the current incomplete local day for completion metrics and selected days whose immediately following local date has not completed for next-day revisit.

Render the live report separately as `daily-focus-v1.json` in the existing App Group container only after ordinary execution is deliberately enabled.
Write it atomically on genuine app activation, following the existing retention-baseline lifecycle.
The existing retention and onboarding report formulas and files remain unchanged.

## Dormant Gate And Rollout

In DEBUG builds, `-dailyFocusLoopEnabled` enables the feature for automated tests and simulator QA.
Without that argument, DEBUG builds use the existing dungeon flow.
Release builds ignore the argument and use the existing dungeon flow while the AND-34 observation hold remains in force.

The dormant implementation must not create `DailyFocusSelection` records, change quest ordering, collapse existing content, or write `daily-focus-v1.json` unless the gate is enabled.
Previews remain on explicit fixture state and do not persist focus selections.

Enabling the feature for ordinary execution is a separate rollout decision after the AND-34 cohort has closed and seven complete local calendar days have made D7 eligible.
That later rollout must define its effective timestamp so `DailyFocusReport` can exclude earlier app-active days from the selection-rate denominator.

## Accessibility

VoiceOver reads the section title, progress, selected quests, edit action, and remaining-quest disclosure in visual order.
The explicit confirmation and edit confirmation state the selected count.
The selection list exposes each quest's selected state without relying on color alone.

The layout supports Dynamic Type without truncating actions or requiring horizontal scrolling.
Collapsed content remains discoverable as a disclosure control with its current count.
Reduced Motion may reduce battle animation but must not hide completion state or focus progress.
All actions retain platform-appropriate touch targets.

## Error Handling

Recommendation derivation is pure and cannot block the existing quest list.
Malformed or unsupported snapshots are ignored for presentation and surfaced in report quality counts.

If the installation identity is unavailable or a selection cannot be saved, the feature falls back to the existing full dungeon for that launch state.
It does not synthesize a confirmation, retry silently in a loop, or claim selection success.

If a referenced quest no longer exists, presentation filters it as described above while the immutable snapshot remains available for measurement quality and historical intent.
No failure path changes quest facts or AND-34 records.

## Verification

Pure tests cover:

- deterministic recommendation ordering and the one-to-three cap;
- empty and overloaded candidate sets;
- local-day and time-zone boundaries;
- first confirmation, no-op duplicate, valid revision, and invalid ordering;
- immutable snapshot encoding and model-container migration;
- effective latest-snapshot derivation;
- deletion and completion without automatic replacement;
- each report numerator, denominator, deduplication rule, right-censoring rule, and quality count;
- dormant-gate behavior and launch-argument parsing;
- restoration of `arrow.uturn.forward` for both `내일 도전하기` actions.

UI tests cover:

- recommendations do not count until `오늘 이대로 시작` is selected;
- editing one to three recommendations before confirmation;
- confirmed focus persistence after relaunch on the same local day;
- completion progress with no automatic replacement;
- explicit revision after confirmation;
- collapsed and expanded remaining quests;
- daily graves remaining separate;
- empty selection and more-than-three validation;
- the existing right-swipe completion interaction inside focus and remaining sections;
- the ordinary flow remaining unchanged without `-dailyFocusLoopEnabled`.

Manual simulator QA must observe the full confirm, complete, revise, relaunch, and next-day derivation path with the development launch argument.
It must also launch without the argument and confirm that no AND-35 UI or persisted selection appears.
