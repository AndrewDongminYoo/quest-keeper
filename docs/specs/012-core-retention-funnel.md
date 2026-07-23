# Spec 012 — Core Retention Funnel And Measurement Baseline

Status: approved
Tracks: AND-33
Blocks: AND-34, AND-35, AND-36, AND-37, AND-38, AND-39

## Goal

Define QuestKeeper's first-value and retention funnel before running feature experiments.
Record the minimum local facts needed to measure that funnel, verify event duplicates and omissions with deterministic data, and generate a reproducible baseline without adding an analytics dependency or collecting user-entered content.

## Product Decision

The first value experience occurs when the user saves their first quest and it appears in the dungeon.
This is a separate step from the first quest completion because creating the quest proves that the user crossed the initial setup boundary while completion proves that the core reward loop worked.

Use a local SwiftData event journal in the existing App Group store.
Keep measurement records separate from `Quest`, calculate reports through pure functions over explicit events and time inputs, and write a local JSON baseline when the app becomes active.

Do not add Firebase, another analytics SDK, a backend, an account system, or a user-facing analytics dashboard.
Reconsider an external analytics dependency only after the local baseline proves that a required product question cannot be answered with the approved data.

## Scope

In scope:

- define the core event dictionary and one canonical owner for each event;
- create a local anonymous installation identity and measurement start time;
- store local retention events separately from quest facts;
- record genuine app activations, quest creation, quest completion, and retry tomorrow;
- cover both app and widget completion paths;
- canonicalize duplicate events by a stable deduplication key;
- calculate the first-value funnel, first completion, D1 and D7 retention, weekly active installations, and weekly repeated completion;
- reject or report invalid, unsupported, out-of-order, duplicate, and incomplete data without guessing;
- generate a deterministic Markdown fixture baseline and a live local JSON baseline;
- verify privacy, duplicate, omission, forbidden-event, calendar, and report-rendering behavior.

Out of scope:

- network transmission or remote aggregation;
- account, advertising, device-vendor, email, or other durable person-level identifiers;
- quest titles, notification text, free-form input, or other user-entered content in measurement storage or logs;
- a settings screen, analytics dashboard, debug menu, or new user-facing UI;
- experiment assignment or the implementation of AND-34 through AND-39;
- retroactively assigning creation or activation events to quests that existed before measurement started;
- changing game balance, quest outcomes, notification behavior, widget payloads, or the daily-grave model;
- adding analytics properties to `Quest` or storing derived retention metrics.

## Architecture

Add `RetentionInstallation` and `RetentionEvent` as models in the existing App Group SwiftData container.
`Quest` remains unchanged and continues to store only quest facts.

`RetentionInstallation` is a singleton record containing:

- `schemaVersion`;
- a randomly generated anonymous `installationID`;
- `measurementStartedAt`.

`RetentionEvent` contains only:

- an event row UUID;
- `schemaVersion`;
- the event name;
- the anonymous `installationID`;
- `occurredAt`;
- the source, either app or widget;
- an optional quest UUID when the event concerns one quest;
- an opaque stable `deduplicationKey`.

The installation UUID is local measurement scope, not an account or person identifier.
It is not transmitted and exists only to group events in the live report and deterministic multi-installation fixtures.

`RetentionEventRecorder` owns event construction, validation, deduplication lookup, and privacy-safe error logging.
Callers provide the event time and any source fact needed to construct the stable key.

`RetentionReport` is a pure value calculation over events, `asOf`, `Calendar`, and reporting interval inputs.
It must not read global clocks, current time zones, SwiftData, `UserDefaults`, or the network.

`RetentionBaselineWriter` renders the pure report as schema-versioned JSON and saves it atomically in the App Group container.
The app invokes it after recording a genuine activation, so app and widget writes already present in the shared store appear in the next baseline.

Adding measurement models must preserve an existing store and every existing `Quest` row.
Implementation must verify the lightweight schema change against a pre-populated store before relying on it.
If SwiftData requires an explicit versioned migration, implement the smallest migration that adds only the two measurement models and does not synthesize historical events.

## Event Dictionary

### `app_activated`

Meaning: the app reached active state on initial launch or after it had genuinely entered background.

Owner: `QuestKeeperApp`.

Required fields: installation ID, occurrence time, app source, and a per-activation-session deduplication key.

Do not emit for an inactive-to-active transition that never passed through background.
Do not also emit from `ContentView`.

### `quest_created`

Meaning: a new quest was saved and entered the dungeon.

Owner: the new-quest branch in `QuestEditor`.

Required fields: installation ID, occurrence time, app source, quest UUID, and a key derived from installation ID plus quest UUID.

Do not emit when an existing quest is edited, when the editor is cancelled, or when a save does not produce a new quest.
The first valid `quest_created` after measurement starts is the first value experience.

### `quest_completed`

Meaning: a pending quest received a new `completedAt` fact.

Owners: the app completion mutation and `QuestStoreActor` for widget completion.

Required fields: installation ID, the captured `completedAt` as occurrence time, app or widget source, quest UUID, and a key derived from installation ID plus quest UUID plus the exact captured completion time.

Do not emit when an already-completed or missing quest receives a stale or duplicate action.
Completing the same quest after retry tomorrow is a new event because its captured completion time differs.

### `quest_retried`

Meaning: retry tomorrow moved a grave into a new active attempt.

Owner: the app retry-tomorrow mutation.

Required fields: installation ID, occurrence time, app source, quest UUID, and a key derived from installation ID plus quest UUID plus an opaque UUID created once for that retry attempt.

On the first shared-store open after this key format ships, legacy rows with the same deadline-bearing key must receive the same opaque replacement key.
The cleanup is best effort, must not block app or widget behavior, and writes its completion marker only after the normalized rows persist so later container opens do not rescan retry history.

Do not emit for an edit that merely changes a deadline.
This event describes a recovery branch and is not a required step in the core funnel.

## Canonical Funnel

For each installation, order valid canonical events by occurrence time and use the event row UUID as the deterministic tie-breaker.

The core funnel is:

```plaintext
first app_activated
  -> first quest_created after activation
  -> first quest_completed after creation
  -> app_activated on local calendar day 1
  -> app_activated on local calendar day 7
```

The report calculates conversion as of its explicit `asOf` time.
It must include the measurement window, reporting time zone, and eligible denominator for every rate so newer installations are not silently treated as failures.

### First Value Rate

Denominator: installations with a valid first `app_activated` in the report cohort.

Numerator: those installations with at least one later `quest_created` by `asOf`.

### First Quest Completion Rate

Denominator: installations that reached first value.

Numerator: those installations with at least one later `quest_completed` by `asOf`.

An orphan completion without a preceding creation is excluded from the funnel and reported as a data-quality problem.

### D1 And D7 Retention

The cohort date is the local calendar date of the first valid `app_activated` in the report's explicit time zone.

D1 retention requires another valid `app_activated` on the calendar date exactly one day after the cohort date.
D7 retention requires another valid `app_activated` on the calendar date exactly seven days after the cohort date.

The D1 denominator includes only installations whose first activation date is at least one complete calendar day before `asOf`.
The D7 denominator includes only installations whose first activation date is at least seven complete calendar days before `asOf`.
An activation later than the exact target date does not backfill a missed D1 or D7 return.

### Weekly Active Installations

A weekly active installation has at least one valid `app_activated` inside the explicit reporting week.
The report uses the supplied calendar and time zone to determine the week interval and records both interval boundaries.

### Weekly Repeated Completion Rate

Denominator: weekly active installations.

Numerator: weekly active installations with at least two canonical `quest_completed` events inside the same reporting week.

Two completions may belong to different quests or to different retry attempts of the same quest.
Duplicate rows sharing one deduplication key count once.

## Deduplication And Event Ownership

Every event has one canonical owner named in the event dictionary.
Instrumentation must not be added to convenience views, animation callbacks, notification synchronization, or report generation when the canonical owner already emits the event.

The recorder checks for an existing deduplication key before inserting a new row.
A repeated request with the same key is a successful no-op.
The report independently groups by deduplication key because app and widget processes can race before either process observes the other's pending write.

When duplicate rows exist, the report keeps the earliest occurrence and then the smallest event row UUID as the deterministic representative.
It records discarded duplicate counts by event name in `dataQuality` without rendering deduplication keys or quest UUIDs.

## Reliability And Error Handling

When possible, quest creation, app completion, and retry events are inserted through the same `ModelContext` as their quest mutation.
Widget completion inserts its event through the existing `QuestStoreActor` before the actor saves.

Measurement must not become a new reason for a valid quest action to fail.
An event-construction or recorder error is logged and the product mutation continues.
Logs include the event name and error description only and never include a title, quest UUID, installation UUID, deduplication key, notification text, or event payload.

The reporter does not infer missing events or rewrite timestamps.
It classifies the report as `complete` only when every included row is valid and no duplicate, orphan, unsupported, or ordering problem exists.
Otherwise it classifies the report as `partial` and lists counts by reason.

Existing quests and completions before `measurementStartedAt` are not assigned synthetic events.
The first live report therefore starts a new measured cohort and must not claim historical retention.

## Privacy Contract

Allowed event data:

- random local installation UUID;
- event row UUID;
- quest UUID for event identity and duplicate control;
- event name and schema version;
- event timestamp;
- app or widget source;
- opaque deduplication key.

Forbidden event data:

- quest title or any substring, token, hash, length, or classification derived from the title;
- notification title or body;
- deadline, importance, urgency, mob level, grave count, victory count, or other product-state properties not required by the approved metrics;
- Apple account, email, advertising identifier, vendor identifier, device name, contact data, location, or IP address;
- crash logs, console text, or arbitrary property dictionaries.

The local baseline file follows the same contract.
No measurement data leaves the App Group container in this milestone.

## Baseline Artifacts

`docs/notes/012-retention-baseline.md` is generated from a checked-in deterministic fixture with multiple anonymous installations, fixed timestamps, a fixed time zone, and a fixed `asOf` value.
The fixture is synthetic and validates the measurement pipeline; it is not evidence of real QuestKeeper user performance.

The checked-in note records:

- fixture version and report schema version;
- cohort and reporting-week boundaries;
- funnel counts, eligible denominators, and rates;
- D1 and D7 eligible cohorts and retained counts;
- weekly active and repeated-completion counts;
- data-quality status and duplicate, omission, forbidden-event, unsupported, and orphan counts;
- the exact verification command used to reproduce it.

The live report is `retention-baseline-v1.json` in the existing App Group container.
It is regenerated atomically after a genuine app activation and contains the same metric and data-quality fields as the Markdown fixture baseline.
Widget completion is reflected after the next app activation.

There is no user-facing report screen in this milestone.

## Verification

Focused automated coverage must prove:

- the installation record is stable and contains no account identifier;
- every event type accepts only its approved fields;
- duplicate recorder requests are no-ops;
- duplicate rows are canonicalized and reported;
- edit, cancelled creation, inactive-only transitions, and repeated widget completion emit no forbidden event;
- app and widget completion each emit one event for one new completion fact;
- retry tomorrow emits one recovery event and a later completion remains distinct;
- removing an expected fixture event reports the exact omission;
- inserting a duplicate fixture event reports the exact duplicate;
- first-value and first-completion denominators follow the funnel order;
- D1 and D7 denominators exclude installations that have not completed the observation window;
- D1 and D7 require activation on the exact local calendar date;
- weekly boundaries use the supplied calendar and time zone;
- weekly repeated completion counts canonical events only;
- unsupported, orphan, future, and pre-measurement rows make the report partial rather than guessed;
- the rendered Markdown exactly matches the checked-in baseline note;
- the live JSON writer uses atomic replacement and rejects an unsupported report schema;
- opening a pre-populated Quest store after the schema change preserves every existing quest.

Use the single-worker project gate:

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
git diff --check
```

A focused privacy test must reject an injected forbidden payload before its passing result is trusted against the production event constructors.

Manual simulator verification:

1. install a fresh build and launch the app;
2. create one quest and confirm it appears in the dungeon;
3. complete it in the app;
4. background and reactivate the app;
5. create another quest and complete it from the widget;
6. reactivate the app;
7. inspect `retention-baseline-v1.json` in the App Group container;
8. confirm the first activation, first value, app completion, later activation, and widget completion appear once in the calculated report;
9. confirm the JSON contains no quest title or other user-entered text;
10. confirm the app and widget behavior remain unchanged.

## Acceptance Criteria

- The event dictionary names one canonical owner, occurrence point, required fields, and forbidden cases for all four events.
- The first value experience is the first saved quest displayed in the dungeon and remains separate from first completion.
- `Quest` gains no analytics or derived retention property.
- The local App Group store preserves existing quests while adding installation and event records.
- App and widget completion paths record one canonical event for one new completion fact.
- Deterministic tests identify exact duplicates, omissions, and forbidden emissions.
- Funnel, D1, D7, weekly active, and weekly repeated-completion calculations use explicit times, calendars, time zones, and eligible denominators.
- The checked-in Markdown fixture baseline is reproducible and clearly labeled synthetic.
- The live local JSON baseline is regenerated after app activation and reports incomplete data honestly.
- Measurement storage, logs, and reports contain no user-entered content or durable person-level identifier.
- No analytics dependency, backend, network transmission, account system, or user-facing dashboard is added.
- `QuestKeeperTests` pass with parallel testing disabled and one test worker.
