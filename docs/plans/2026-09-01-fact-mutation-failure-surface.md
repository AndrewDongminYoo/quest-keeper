# Implementation Plan — A Failure Surface for a Rejected Fact Mutation

Contract: `docs/specs/025-fact-mutation-failure-surface.md`. Tracked as GitHub issue #67.

## Sequence

1. **`ContentView.commitPendingChanges()`** — set `lastCommitFailed` on both branches of the existing `do`/`catch`, and leave the `hasChanges == false` early return alone.
   No call site changes; the nine callers keep their present shape.

2. **`ContentView`** — one `@State private var lastCommitFailed = false`, passed to `HomeDungeonBoardView` beside `storeFailedToOpen`.

3. **`AppStrings` + the app catalog** — `commit.failure.banner.title` and `commit.failure.banner.body`, Korean `defaultValue` with an English peer.
   Insert into `Localizable.xcstrings` as raw text at the sorted position; re-serializing the file reformats all two hundred entries.

4. **`HomeDungeonBoardView`** — a `CommitFailureBanner` built like `StoreFailureBanner`, rendered under the same condition slot.

5. **`LaunchArguments` + `commitPendingChanges`** — `-uiTestingRejectSaves`, throwing inside the same `do` block the real failure lands in, under `#if DEBUG`.
   This mirrors `storeFailureFixtureEnabled` exactly, including its reason: there is no way to make a real store reject a save from a test, and setting the flag directly would assert nothing about the path that runs.

6. **`QuestKeeperUITests`** — one test on the `StoreFailureUITests` pattern: seed a board, tap a completion, assert the banner exists, assert its words, assert the quest is still there uncompleted.

## Verification order

`swiftc -typecheck` first. Then the unit suite plus the new UI test in one background run — the UI-test runner's build cost is already sunk by any unit-test invocation, so running a targeted UI test afterwards is nearly free.

Prove the UI test can fail before trusting it: launch the same flow **without** `-uiTestingRejectSaves` and confirm the banner assertion fails rather than the whole test passing for a different reason.

## Risks

**The fixture must throw where the real failure throws.**
Setting `lastCommitFailed` directly from the launch argument would produce a green test over a path that never ran — the exact trap `storeFailureFixtureEnabled`'s comment was written to prevent.

**A no-op commit must not clear the flag.**
`guard modelContext.hasChanges else { return true }` returns success without saving. Clearing there would let any later view update erase a warning about a write that really was rejected.

**The banner has to survive the sheet's dismissal.**
The detail sheet's actions set the flag and then the sheet closes; the board must already be observing the flag rather than being told by the sheet.
