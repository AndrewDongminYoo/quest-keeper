# Spec 013 — First-Value Onboarding Experiment

Status: design approved; written spec pending review
Tracks: AND-34
Depends on: AND-33

## Goal

Compare the current first-use flow with a guided flow that helps a newly measured installation save and complete one small quest within two minutes.
Assign each eligible installation to one variant exactly once, preserve the assignment across launches and updates, and keep the observation window free from overlapping first-value experiments.

## Product Decision

Run a 50:50 installation-level A/B experiment under the key `and-34-first-value-v1`.
The control variant keeps the current empty-dungeon experience.
The guided variant offers a prefilled quest editor, still requires the user to save the quest, and then guides the user to complete that quest in the dungeon.

The first value boundary remains the first saved quest appearing in the dungeon, as defined by Spec 012.
Automatic quest creation is forbidden because it would move that boundary without a deliberate user action.

This experiment is shame-free.
It may encourage a small first action and celebrate completion, but it must not introduce streak pressure, punishment, permanent failure language, guilt-driven copy, or coercive notifications.

## Scope

In scope:

- assign eligible installations once to control or guided with an unbiased random 50:50 choice;
- persist the assignment as a separate immutable SwiftData fact;
- preserve the assigned variant across launches and app updates;
- exclude pre-existing and unassigned installations from experiment comparison;
- record experiment exposure, quest-creation start, and explicit deferral;
- join those events with the existing quest-created, quest-completed, and app-activated facts;
- render a pure local experiment report with explicit cohort and observation boundaries;
- add a guided empty state, prefilled editor entry, completion guidance, and session-only deferral;
- restore the appropriate guided state after cancellation or process restart;
- verify accessibility, empty-state behavior, interruption recovery, assignment stability, and right-censored metrics.

Out of scope:

- remote analytics, network transmission, accounts, or person-level identity;
- automatic experiment winner selection;
- treating deterministic fixtures as population-level evidence;
- retroactive assignment of existing installations;
- changing the core retention funnel or the meaning of existing events;
- changing quest balance, deadline outcomes, notifications, widgets, graves, or retry behavior;
- running AND-35 or AND-38 concurrently with the AND-34 observation window;
- adding experiment or onboarding properties to `Quest`;
- a generalized experimentation framework for unrelated future features.

## Experiment Definition

The experiment key is `and-34-first-value-v1`.
The variants are `control` and `guided`.

Changing the UI flow, assignment rule, event semantics, metric formulas, or eligibility rule requires a new experiment key.
Data recorded under different experiment keys must never be merged into one cohort.

An unbiased random bit selects the variant when a new assignment is created.
The choice is expected to approach a 50:50 split across independent eligible installations; the implementation must not alternate assignments or rebalance existing records.
Tests inject a deterministic variant selector instead of depending on process randomness.

## Eligibility And Enrollment

An installation is eligible only when all of the following are true during initial app bootstrap:

- no `RetentionInstallation` exists;
- no `ExperimentAssignment` exists for the experiment key;
- no persisted `Quest` exists.

The app creates the `RetentionInstallation` and `ExperimentAssignment` before choosing the first-use UI.
The assignment and installation use the same installation UUID.
The later first `app_activated` event reuses that installation record.

If a `RetentionInstallation` or any quest already exists without an AND-34 assignment, the installation is pre-existing.
It continues through the current product flow but is excluded from both experiment variants.
No update, migration, or later activation may backfill an AND-34 assignment for it.

Assignment failure must not block the app.
The app falls back to the current product flow and excludes the installation from the experiment report.

## Persistent Assignment

Add `ExperimentAssignment` to the existing App Group SwiftData schema.
It contains only:

- `schemaVersion`;
- `experimentKey`;
- `installationID`;
- `variantRawValue`;
- `assignedAt`.

The initializer is the only supported write path.
Production code exposes no API that changes an assignment after creation.
The assignment owner runs only in the app process on the main actor; the widget never assigns a variant.

The recorder checks for an existing assignment with the same experiment key and installation ID before insertion.
A repeated request returns the existing assignment.
Multiple rows or conflicting variants for the same experiment key and installation ID make the experiment report partial and exclude that installation from performance metrics.

`Quest` remains unchanged.
Experiment assignment is measurement metadata and is not a quest fact or derived gameplay state.

## Event Dictionary

The experiment adds three event names to the existing retention event journal.
They retain the existing privacy contract and contain no user-entered content.

### `experiment_exposed`

Meaning: the assigned first-use surface became visible for the first time.

Owner: the root first-use surface after it has resolved an eligible assignment.

Required fields: installation ID, occurrence time, app source, no quest UUID, and a deduplication component containing the experiment key.

Emit once per installation and experiment key for both control and guided variants.
The two-minute clock starts at this event, not at assignment creation or process launch.

Do not emit for pre-existing installations, assignment failures, previews, or background-only work.

### `quest_creation_started`

Meaning: the user intentionally opened a new-quest editor from the assigned first-use surface.

Owner: every new-quest action on the assigned first-use surface before presenting `QuestEditor`, including the header action and both guided-card create actions.

Required fields: installation ID, occurrence time, app source, no quest UUID, and a per-action deduplication component.

Record both the guided template entry and the guided `직접 만들기` entry under the same event name.
Do not emit for edit routes, notification routes, automatic view updates, or editor cancellation.

### `onboarding_deferred`

Meaning: a guided installation explicitly selected `나중에`.

Owner: the guided empty-state action.

Required fields: installation ID, occurrence time, app source, no quest UUID, and a per-app-run deduplication component.

This event is valid only for the guided variant.
It hides the guided card for the current process lifetime but does not permanently opt the installation out.

## Canonical Experiment Funnel

For one valid assignment, consider canonical valid events at or after the first matching `experiment_exposed` event.
Order events by occurrence time and use the event row UUID as the deterministic tie-breaker, matching Spec 012.

The experiment funnel is:

```plaintext
experiment_exposed
  -> quest_creation_started
  -> first quest_created
  -> quest_completed for that first quest
  -> app_activated on local calendar day 1
  -> app_activated on local calendar day 7
```

The first quest is identified by the quest UUID on the first valid `quest_created` after exposure.
The completion step requires a later canonical `quest_completed` for that same quest UUID.
A completion for another quest does not complete the onboarding funnel.

Events before exposure are excluded and reported as ordering failures when they claim to belong to an assigned installation's experiment path.
The reporter does not infer an exposure, creation start, creation, completion, or return event.

## Guided User Experience

The control variant keeps the existing empty-dungeon UI and behavior.
Only measurement is added to its first-use create action.

The guided variant replaces the initial empty state with:

- title: `첫 승리를 시작해볼까요?`;
- explanation: `2분 안에 끝낼 수 있는 작은 전투부터 시작하세요.`;
- primary action: `2분 전투 시작`;
- secondary action: `직접 만들기`;
- deferral action: `나중에`.

The primary action opens the existing quest editor prefilled with:

- title: `물 한 잔 마시기`;
- deadline: ten minutes after the editor is created;
- importance: low.

All fields remain editable.
The user must press the existing `저장` action before a quest is inserted and `quest_created` is recorded.
The guided flow must not auto-save, auto-complete, or request notification permission earlier than the existing save path.

After the first quest is saved, show `완료하면 첫 승리를 얻어요` as guidance associated with that pending quest.
The existing completion control remains the only completion action.
The guidance disappears after a canonical completion for that quest.

## Interruption And Re-entry

Guided state derives from the immutable assignment, canonical experiment events, and current quests.
Persist no mutable `hasCompletedOnboarding` flag.

- Cancelling the editor before save returns to the guided card.
- Selecting `나중에` hides the card only for the current process lifetime.
- Terminating before the first save shows the guided card again on the next launch.
- Terminating after save but before completion restores guidance for the first pending quest.
- Completing the first quest ends the guided experience.
- Deleting the first quest before completion returns to the ordinary empty state and remains an incomplete completion step in the report.

Session-only deferral belongs to app-level transient state so refreshing the SwiftData container after a background transition does not redisplay the card during the same process lifetime.

## Accessibility

The guided flow must remain operable without animation or a countdown display.
It must not auto-advance when a timer expires.

VoiceOver reads the title, explanation, primary action, secondary action, and deferral action in that order.
The first-quest completion guidance is associated with the target quest and does not replace the completion control's existing accessibility label.

The layout must support Dynamic Type without truncating actions or requiring horizontal scrolling.
All actions retain platform-appropriate touch targets.
Reduced Motion must not remove information or prevent progress.

## Experiment Report

Add a pure `OnboardingExperimentReport` calculation beside, not inside, `RetentionReport`.
It accepts explicit assignment snapshots, installation snapshots, event snapshots, `asOf`, calendar, cohort interval, and reporting time zone.
It must not read SwiftData, global clocks, `UserDefaults`, view state, or the network.

The report groups only valid eligible assignments by variant and calculates:

- onboarding completion rate: installations reaching first `quest_created` within two minutes of exposure divided by exposed installations whose two-minute observation window has matured;
- two-minute first-success rate: installations completing their first created quest within two minutes of exposure divided by exposed installations whose two-minute observation window has matured;
- first-quest completion rate: installations later completing their first created quest divided by installations that reached first value;
- time to first value: duration from exposure to first `quest_created`, summarized by variant with a median when at least one duration exists;
- stage drop-off counts between exposure, creation start, creation, and completion;
- guided deferral rate: guided installations with at least one canonical `onboarding_deferred` divided by guided exposed installations;
- D1 and D7 retention by assigned variant using exact local calendar dates.

The report includes numerator, eligible denominator, rate, cohort interval, `asOf`, and time zone for every rate.
An empty denominator renders no rate rather than zero percent.

The existing `RetentionReport` formulas and output remain unchanged.
Its established first-value and retention report remains the canonical product baseline; the experiment report is a cohort comparison layered over the same source facts.

Render the live experiment report as `onboarding-experiment-v1.json` in the existing App Group container.
Refresh it after a genuine app activation, matching the existing retention-baseline lifecycle, so events from the preceding foreground session appear after the next activation.
Write it atomically and keep its output separate from `retention-baseline-v1.json`.

## Observation Windows And Non-contamination

The report accepts an explicit half-open enrollment interval from cohort start through, but excluding, cohort end.
Concrete live enrollment dates are not defined in this spec and must not be guessed or hardcoded before a live observation window is deliberately selected.

Two-minute metrics include only installations whose exposure occurred at least two complete minutes before `asOf`.
D1 includes only installations whose first exposure date is at least one complete local calendar day before `asOf`.
D7 includes only installations whose first exposure date is at least seven complete local calendar days before `asOf`.
An activation after a missed target date does not backfill D1 or D7.

Freeze other changes that can alter first creation, first completion, or D1 from the first eligible AND-34 exposure through seven complete local calendar days after cohort enrollment closes.
Do not deploy AND-35 or AND-38 inside that interval.
D1 is preliminary only after one complete local calendar day has passed since cohort close.
D7 is available only after seven complete local calendar days have passed since cohort close.

The report excludes an installation from performance metrics and marks data quality partial for:

- missing assignment or exposure;
- multiple or conflicting assignments;
- assignment and event installation-ID mismatch;
- unsupported variant or schema version;
- exposure before assignment;
- creation start, creation, or completion before exposure;
- completion before creation or for a different first-quest identity;
- duplicate canonical keys.

An assignment outside the explicit cohort interval is outside the report population and does not by itself degrade data quality.
Ordinary activity after a matured observation boundary also remains valid source data; the metric includes or excludes it according to its stated window without labeling it malformed.

## Evidence And Decision Policy

Deterministic fixtures verify assignment grouping, event ordering, metric formulas, right-censoring, and rendering.
They are not evidence that either variant improves real-user behavior.

The local report remains exploratory until the operator deliberately supplies enough independent eligible installations or another evidence source for a decision.
The report must not declare a winner, significance, confidence interval, or uplift conclusion automatically.
Until a separate decision rule is approved, describe observed variant differences as counts and rates only.

## Privacy Contract

The experiment inherits Spec 012's privacy contract.
Allowed additional data is limited to the experiment key, assigned variant, assignment timestamp, and the three approved event names.

Do not store or render quest titles, notification content, account identifiers, device identifiers, contact data, location, IP address, or arbitrary properties.
The prefilled title is ordinary quest content and remains only on the `Quest`; it must never be copied into an assignment, retention event, experiment report, or log.

No experiment data leaves the App Group container in this milestone.

## Reliability And Error Handling

Experiment measurement must not make a valid quest action fail.
Assignment, event-recording, or report-writing failures use privacy-safe logging and preserve the current product flow.

If assignment resolution is unavailable when choosing the first-use UI, use the current flow for that process and exclude the installation from experiment metrics.
Do not later switch a visible control flow to guided during the same process.

The report is strict and deterministic.
It rejects unsupported or contradictory rows instead of repairing, guessing, or silently including them.

## Verification

Automated coverage must verify:

- deterministic control and guided selection through an injected variant selector;
- one assignment per eligible installation and stable reuse across relaunches;
- existing installations and stores containing quests receive no assignment;
- assignment failure preserves the current UI and excludes measurement;
- control and guided exposure events are each emitted once;
- create actions emit one canonical `quest_creation_started`, while edit and cancellation do not create false progress;
- `나중에` is session-only and deduplicated per process run;
- the guided template requires an explicit save and records no title in measurement storage;
- cancellation, termination before save, termination after save, completion, and deletion restore the specified state;
- only completion of the first created quest completes the experiment funnel;
- two-minute denominators exclude immature exposures;
- D1 and D7 use exact local calendar dates and right-censored denominators;
- conflicting assignments, invalid order, duplicates, unsupported values, and cross-installation mismatches make report quality partial;
- report rendering is deterministic and contains no forbidden content;
- a pre-populated SwiftData store preserves every quest while adding the assignment model;
- VoiceOver labels and reading order expose every guided action;
- the guided card and editor remain usable at accessibility Dynamic Type sizes and with Reduced Motion enabled.

Manual QA must exercise both forced variants on the pinned iPhone simulator.
For each variant, launch from a clean eligible store, verify the expected first-use surface, create the first quest, complete it, background and reactivate the app, and inspect the local experiment report.
For guided, also cancel before save, defer for the current run, relaunch, save and terminate before completion, relaunch again, and delete the guided quest before completion in a separate clean run.

## Acceptance Criteria

- Every eligible installation receives exactly one persistent control or guided assignment and never changes variants.
- Existing or already-used installations are not retroactively enrolled.
- Control behavior remains visually unchanged.
- Guided users can choose the template, create a quest manually, or defer without coercion.
- The template path requires explicit save and explicit completion through existing product actions.
- Guided progress restores correctly after every specified interruption.
- The report compares variants using explicit cohort, two-minute, D1, and D7 eligibility rules.
- Invalid or contaminated data is excluded and reported rather than repaired.
- The core retention report and `Quest` schema semantics remain unchanged.
- No user-entered content or person-level identifier enters experiment measurement.
- Fixtures remain calculation evidence only and the implementation declares no automatic winner.
- Automated tests, app build, and manual simulator QA pass for both forced variants.
