# Spec 015 — Recovery Loop Prototype

Status: approved for implementation
Tracks: AND-36
Builds on: AND-35

## Goal

Help a returning user enter the daily loop without streak pressure, accumulated-failure framing, or automatic changes to existing quest facts.
Compare two low-cost DEBUG prototypes before choosing a production recovery flow or defining a population experiment.

## Product Decision

Reuse the existing activation reconstruction interval instead of adding a persisted recovery episode.
The app derives recovery eligibility once from the prior `lastOpened` value and the current activation, advances `lastOpened`, and may present one transient recovery card for that activation.
Closing the card consumes the opportunity without punishment or repeated prompting.

A normal one-day gap is not a recovery event.
The user is eligible only after at least two complete local calendar dates passed between activations or at least two quests became graves during the away interval.

The prototypes compare a one-quest recommendation with an explicit one-to-three quest choice.
Both variants require an active user choice before recording today's focus.
They never modify an old quest automatically.

## Required Invariants

The recovery loop must preserve the following rules:

- do not change an existing quest's deadline, completion time, importance, or title automatically;
- do not retry, complete, delete, or replace an existing quest automatically;
- preserve accumulated victories and all existing quest records;
- preserve prior `DailyFocusSelection` snapshots without mutation;
- keep `내일 도전하기` as the only action that explicitly moves a grave into a future active attempt;
- do not show missed-day counts, missed-quest counts, streak loss, accumulated failure, or permanent defeat;
- do not use guilt, urgency pressure, loss aversion, or coercive notification language;
- keep normal quest use available when recovery derivation, presentation, or focus persistence fails.

These invariants apply to both prototype variants and every fallback path.

## Scope

In scope:

- derive recovery eligibility from the existing activation reconstruction inputs;
- treat a one-day gap as ordinary behavior;
- treat two complete local dates away or two graves created while away as recovery eligibility;
- show a dismissible recovery card at the top of the home board for one activation;
- compare `singleQuest` and `chooseToday` through explicit DEBUG launch arguments;
- reuse AND-35 recommendation ordering and immutable focus confirmation;
- keep today's daily graves and the rest of the dungeon visible below the card;
- provide an existing quest-creation fallback when historical quests exist but no pending quest exists;
- verify dormant, date-boundary, repeated-activation, selection, dismissal, empty, accessibility, and failure behavior;
- document why DEBUG prototype evidence is not population-level retention evidence.

Out of scope:

- installation-level experiment assignment;
- random 50:50 allocation;
- `RecoveryEpisode`, `RecoveryDecision`, or another SwiftData recovery model;
- recovery-specific retention events or reports;
- changing `RetentionReport`, `OnboardingExperimentReport`, or `DailyFocusReport` formulas;
- enabling recovery in Release builds;
- enabling recovery without the AND-35 daily-focus gate;
- changing notification, widget, grave, deadline, victory, or retry derivation;
- automatically confirming a new quest created from the empty fallback;
- declaring a winning recovery flow from developer fixtures or manual preference alone;
- measuring AND-35 and AND-36 population effects in the same observation window.

## Recovery Eligibility

Recovery eligibility is a pure value derived from:

- `previousLastOpened`;
- activation time `now`;
- an explicit Gregorian calendar and time zone;
- the existing `deathsWhileAway` result;
- whether any stored quest exists;
- whether today's daily focus already has a valid confirmation;
- the selected DEBUG recovery variant.

A first activation with no `previousLastOpened` is ineligible.
An installation with no stored quest is ineligible so the existing onboarding flow remains authoritative.
An installation that already has a valid focus confirmation for the current local day is ineligible because it has already re-entered the daily loop.
Disabled or malformed variant configuration is ineligible.

Calculate complete local dates away as follows:

1. Derive the local start of day for `previousLastOpened` and `now` with the supplied calendar.
2. Calculate the number of local date boundaries between those starts.
3. Subtract one so the previous activation date and current incomplete date do not count.
4. Clamp the result to zero.

For example, returning on Thursday after a Monday activation has Tuesday and Wednesday as two complete local dates away.
Returning on Wednesday after a Monday activation has only Tuesday as one complete local date away and does not qualify by time alone.

The installation is eligible when either condition is true:

- complete local dates away are at least two;
- `deathsWhileAway` contains at least two unique quest IDs.

The existing death reconstruction defines the away interval as `(previousLastOpened, now]` and includes only quests whose deadlines fell inside that interval and whose current outcome is grave.
Do not count the current total grave backlog because that would replay older failures and repeatedly prompt the user.

Production derivation uses the current calendar time zone for both interval endpoints.
Tests inject the calendar, time zone, and all timestamps.

## Activation Lifecycle

The activation sequence is fixed:

```plaintext
read previous lastOpened
→ reconstruct deathsWhileAway
→ derive recovery eligibility
→ advance lastOpened to now
→ present a transient recovery card when eligible
```

Eligibility must be derived before `lastOpened` advances.
The persisted `lastOpened` value remains the existing single-use replay boundary.
No recovery receipt is written.

The recovery card is activation state, not timeline-derived state.
Periodic view refreshes must not recreate it.
Closing the card removes it for the current activation.
Relaunching after dismissal uses the advanced `lastOpened`, so the same away interval is not eligible again.
If the process exits before the user acts, the prompt is not replayed; avoiding pressure is preferred over guaranteeing another exposure.

A later activation may create a new recovery opportunity only when it independently satisfies the approved time-away or missed-quest condition.

## Prototype Gates

Support two DEBUG-only launch arguments:

- `-recoveryLoopVariant singleQuest`;
- `-recoveryLoopVariant chooseToday`.

Recovery also requires the existing `-dailyFocusLoopEnabled` argument.
If the daily-focus gate is absent, the recovery variant is absent, or the variant value is unsupported, recovery remains disabled.

Release builds ignore recovery launch arguments and preserve the current product flow.
Previews receive explicit fixture state and never infer recovery from process arguments.

The prototype gate must not create data, change ordering, or alter the board when disabled.

## Shared Recovery Card

The recovery proposal is a non-modal card at the top of the home board.
The existing header, dungeon, daily-focus content, and `오늘의 무덤` remain visible below it.
The card never blocks ordinary quest actions.

Shared copy:

- title: `다시 와서 반가워요`;
- description: `쉬었다 와도 괜찮아요. 오늘 할 일부터 가볍게 시작해볼까요?`;
- secondary action: `지금은 괜찮아요`.

Do not display:

- how many days the user was away;
- how many quests were missed;
- a streak or broken-streak state;
- `실패`, `밀림`, `복구`, punishment, or permanent-loss language.

Selecting `지금은 괜찮아요` removes the card and leaves the normal board unchanged.
It does not create a focus confirmation, retry a grave, or write a recovery record.

## Variant A — `singleQuest`

Use `DailyFocusState.rankedPendingQuestIDs` to choose the highest-ranked current pending quest.
Show that quest's title and current Korean deadline presentation inside the recovery card.

The primary action is `이 퀘스트로 다시 시작`.
The button is an explicit choice of the displayed quest.
On success, append a one-quest `DailyFocusSelection` confirmation for the current local day through the existing recorder.
Remove the recovery card only after persistence succeeds and let the existing confirmed focus presentation take over.

Revalidate the displayed quest and current recommendation at tap time.
If the quest is no longer pending or no longer the first recommendation, do not save stale intent.
Refresh or preserve the recovery card with a neutral explanation so the user can choose again.

Do not retry a grave or change any quest facts as part of this action.

## Variant B — `chooseToday`

Do not emphasize an individual quest inside the recovery card.
The primary action is `오늘 다시 고르기`.

Open the existing one-to-three daily-focus selection surface with current pending quests in AND-35 recommendation order.
The user must explicitly confirm one to three quests before a `DailyFocusSelection` is appended.
Remove the recovery card only after persistence succeeds.

Canceling the selection surface returns to the still-visible recovery card.
The user may then choose again, dismiss the card, or use the normal board.

Do not create a separate recovery selection model or a second focus recorder.

## No-Pending Fallback

When historical quests exist but no current pending quest exists, both variants show `작은 퀘스트 만들기` as the primary action.
This opens the existing guided quest-creation flow.

Canceling creation returns to the recovery card.
Saving the quest returns to normal derived presentation, where the new pending quest can enter the existing daily-focus flow.
Do not auto-confirm the new quest because quest creation is not the AND-35 daily-focus selection boundary.

If no stored quest exists at all, do not show the recovery card; preserve existing onboarding behavior instead.

## Existing Quest And Achievement Preservation

Recovery presentation reads existing facts but writes no quest mutation by itself.
Only the user's existing explicit actions may mutate a quest:

- quest editor save creates or edits a quest;
- right-swipe `완료` completes a pending quest;
- `내일 도전하기` retries a visible daily grave;
- explicit delete removes an eligible quest.

Recovery confirmation writes only an immutable `DailyFocusSelection` through the existing supported path.
It does not add recovery fields to `Quest` or mutate prior selection snapshots.

Total victories remain derived from completion facts and are never reset for recovery.
Old graves remain hidden or visible under the existing daily-grave rules rather than being erased, counted as a penalty, or moved automatically.

## Failure Handling

Recovery must be fail-open for ordinary quest use.

- Eligibility derivation failure or unavailable inputs show the existing home board.
- Unsupported launch arguments disable recovery rather than selecting a fallback variant.
- A stale single-quest recommendation is not persisted.
- Focus persistence failure keeps the recovery card or selection surface open and shows a neutral explanation.
- Quest creation cancellation or failure returns to a usable home flow and preserves existing facts.
- No recovery failure changes a quest deadline, completion, importance, title, victory, retry state, or historical selection.

Error copy must describe changed or unavailable state without blaming the user.
Do not use `실패했습니다` for a recoverable product-state conflict.

## Measurement Isolation

AND-36 prototype sessions are development evidence only.
Do not infer retention improvement, flow superiority, or population preference from simulator fixtures, UI automation, or developer review.

This prototype adds no installation assignment, recovery event, recovery report, or population cohort.
It does not change existing retention, onboarding experiment, or daily-focus report formulas.

Any `DailyFocusSelection` created by a DEBUG prototype remains development-only because the AND-35 feature and report are dormant in ordinary execution.
Do not use dates or installations from DEBUG launch-argument sessions as population evidence.

After one recovery flow is selected, a separate rollout specification must define:

- a stable cohort or deliberately chosen evidence source;
- a production exposure boundary;
- observation windows and right-censored denominators;
- return within seven days;
- quest completion on the return date;
- subsequent disengagement;
- an isolation rule that prevents simultaneous AND-35 and AND-36 population effects from being attributed to either experiment.

Do not enable AND-36 in Release while the relevant AND-35 observation window is active.

## Accessibility

VoiceOver reads the recovery title, supportive description, optional recommended quest, primary action, and dismissal action in visual order.
The card does not rely on color to communicate eligibility or action state.

Dynamic Type must not truncate the primary or dismissal action or require horizontal scrolling.
The optional quest title may wrap vertically.
The board remains reachable without dismissing the card.

Reduced Motion may reduce card or focus transitions but must not hide the result of an explicit selection.

## Automated Verification

Pure eligibility coverage includes:

- no `previousLastOpened` is ineligible;
- no stored quest is ineligible;
- an existing current-day focus confirmation is ineligible;
- a one-day ordinary gap is ineligible;
- exactly one complete local date away is ineligible;
- exactly two complete local dates away is eligible;
- two unique graves in the away interval are eligible even without the time threshold;
- one grave in the away interval is insufficient without the time threshold;
- older grave backlog outside the interval does not affect eligibility;
- calendar and time-zone boundaries are deterministic;
- disabled, missing, and unsupported variants are ineligible.

Activation and UI coverage includes:

- eligibility is calculated before `lastOpened` advances;
- the same away interval is surfaced once;
- dismissal preserves all existing facts and normal board actions;
- `singleQuest` confirms exactly the current first recommendation;
- a stale `singleQuest` candidate is not saved;
- `chooseToday` opens the existing selection surface and requires explicit confirmation;
- canceling selection returns to the recovery card;
- no-pending fallback opens guided quest creation without auto-confirming the new quest;
- focus persistence failure keeps a recovery path visible;
- Release and ungated DEBUG execution remain behaviorally unchanged;
- existing deadlines, completions, victories, grave derivation, and historical selections remain unchanged.

## Manual QA

Use one deterministic fixture for both DEBUG variants.
The fixture must include prior quest history, no current-day focus confirmation, and enough elapsed local dates or away-window graves to qualify.

For each variant, inspect:

- supportive copy and absence of failure counts;
- board visibility and immediate dismissal;
- number of decisions before entering confirmed daily focus;
- correct selected quest or selection surface;
- unchanged daily graves and historical victories;
- VoiceOver order and labels;
- Dynamic Type wrapping;
- behavior after canceling or encountering stale state.

Record the comparison as prototype evidence, not population-level uplift evidence.

## Acceptance Criteria

- A normal one-day gap does not show recovery.
- Two complete local dates away or two graves during the away interval may show one recovery card.
- The card appears at most once for that activation interval and is freely dismissible.
- `singleQuest` and `chooseToday` can be reviewed independently through DEBUG launch arguments.
- A user with pending quests can enter the daily focus loop through one explicit recovery choice or one explicit selection confirmation.
- A user with no pending quest can enter existing guided creation without automatic focus confirmation.
- Existing quest facts, victories, graves, retries, and prior focus selections are preserved.
- Disabled and Release execution remain unchanged.
- The implementation adds no recovery persistence, assignment, event, or report.
- Automated and manual validation distinguish prototype usability evidence from future retention evidence.
