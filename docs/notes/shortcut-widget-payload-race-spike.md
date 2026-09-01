# Shortcut Widget Payload Race — Two-Process Reproduction Spike

Working note for issue #65, the follow-up to #56 and #64.
It records a reproduction attempt and its measurement; it changes no behaviour.

## The claim under test

Issue #65 states that a `CompleteQuestIntent` commit landing after `reopenStore()` and before `snapshotPayload()` is still invisible to the reopened container, so the shortcut can publish a widget payload that shows a completed quest as pending.

The claim is an ordering property, not a timing race: `QuestShortcutCreationCoordinator.create` opens its store once at entry and reads the payload from that same store after the notification round trips.
A reproduction therefore only has to control the ordering.
That is what makes the measurement below possible without a pause, a hook, or any other edit inside `create()`.

## Harness

`scripts/spike-65/run.sh [simulator-udid] [runs-per-arm]` — two genuinely separate processes over one store file, gated by files so neither sleeps on a guess.

- Process A stands in for the shortcut: it opens a container, commits its own created quest, reads the board, waits, then re-reads.
- Process B stands in for the widget: it waits, opens its own container, and writes `completedAt` on a quest A already read.

Both are built from the repository's own `@Model` sources.
The type list is read out of `QuestModelContainer.makeSchema()` at run time and each type's file is located by its declaration, so the harness's schema is the production schema rather than a copy of it; a model added to production that the script cannot locate stops the run instead of measuring an older store shape.
A's reads are the two `QuestStoreActor` calls the coordinator makes, in the same order and with the same descriptors:

| Harness step                                      | Production call                                                            |
| ------------------------------------------------- | -------------------------------------------------------------------------- |
| insert + save                                     | `QuestStoreActor.create`                                                   |
| `fetch(FetchDescriptor<Quest>())` before the gate | `QuestStoreActor.snapshots`, handed to `syncAndRefreshReengagement`        |
| `fetch(FetchDescriptor<Quest>())` after the gate  | `QuestStoreActor.snapshotPayload`, which `WidgetDungeonPayload.make` reads |

The store is a copy of the installed app's App Group store — every `default.store*` file present, so the WAL and shared-memory files come along when they exist — taken from `group.kr.donminzzi.QuestKeeper` on simulator `89E4D493-3048-486A-BCC0-3F3D749B3929`.
A copy rather than the live file, so the spike leaves the simulator's own data untouched; the property under test is a per-process coordinator property and does not depend on where the file sits.
The script falls back to a store it creates itself when no app container is installed, which changes nothing about the arms.

The harness was run twice over: as two macOS processes, and as two iOS-simulator processes (`swiftc -target arm64-apple-ios26.5-simulator`, launched with `xcrun simctl spawn`, `LC_BUILD_VERSION platform IOSSIMULATOR minos 26.5`).
The second run removes the only substantive gap in the first, which is that macOS SwiftData is not the framework the app links.

## Arms and controls

- **Arm 1** — A reads the board before the gate, so the payload read happens on a context that already registered those objects. This is the shortcut's real shape.
- **Arm 2** — A skips that first read, so the payload read happens on a context that registered nothing.
- **Positive control** — B commits _before_ A opens its container. A must report the completion, or the harness cannot read the store correctly at all.
- **Negative control** — after the gate, A reads the retained model object without re-fetching, alongside the re-fetch. Without this, an all-fresh verdict would be indistinguishable from a harness structurally unable to observe staleness.

## Result — the claim does not reproduce

41 runs in each environment: 1 positive control, 20 of arm 1, 20 of arm 2.
Every run confirmed B's commit in its own log line before A's second read.

| Reading                                                           | macOS processes   | iOS simulator processes |
| ----------------------------------------------------------------- | ----------------- | ----------------------- |
| Re-fetch after the other process's commit (arms 1 and 2, 40 runs) | fresh 40, stale 0 | fresh 40, stale 0       |
| Retained object read without re-fetch (arm 1, 20 runs)            | stale 20          | stale 20                |
| Positive control                                                  | fresh             | fresh                   |

The negative control is the load-bearing row.
The harness observed staleness in every arm-1 run, so its all-fresh verdict on the re-fetch is a measurement rather than a blind spot.

**A `ModelContext.fetch` sees a commit another process made after the container was opened.**
What does not see it is a model object already registered in that context and read again without a re-fetch.
Both `QuestStoreActor.snapshots` and `QuestStoreActor.snapshotPayload` re-fetch, so neither of the coordinator's reads is exposed.

This is consistent with the earlier warm-foreground observation that motivated #56, if that staleness is at the registered-object level rather than the fetch level — which is what a SwiftUI `@Query` result holds.
`[UNCERTAIN]` — that reading is an inference from the table above, not a measurement: this spike never exercised `@Query`.
Recreating the container on `.active` is measured behaviour and stays; nothing here is a reason to drop it.

## Decision

No implementation.
Neither candidate direction in #65 — a cross-process sequence owned by the App Group, or merging the created quest into the payload already on disk — has a defect to close.

## Accepted risk and what to watch

The residual risk is that a future refactor moves a read from a re-fetch to a retained object, at which point the staleness in the table above becomes reachable and no unit test can see it: two containers in one process share a coordinator cache, so any in-process test of this is a false green (gated since PR #68).

The run asserts the table above rather than printing it: a positive control that reads stale, a negative control that stops observing staleness, or any stale re-fetch exits nonzero and names which expectation broke.
A re-run that exits 0 is therefore evidence the measurement still holds, not merely evidence that the script finished.

Watch these three, and re-run this spike if any of them changes:

- `QuestStoreActor.snapshotPayload` and `QuestStoreActor.snapshots` must each keep issuing their own `fetch`. Deriving the payload from an array an earlier call returned would reintroduce the object-level staleness.
- `QuestShortcutCreationCoordinator.create` must keep deriving the payload from a store read rather than from the `QuestSnapshot` values it already holds.
- A SwiftData major version change, since the measured behaviour is the framework's and not the app's.
