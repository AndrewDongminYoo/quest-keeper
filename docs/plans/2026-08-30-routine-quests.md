# Daily Routine Quests Implementation Plan

## Goal

Implement Linear AND-115 as a narrow daily routine loop with immutable completion facts and no changes to ordinary Quest behavior.

## Scope And Constraints

- Add `RoutineRule` and `RoutineCompletion` to the existing shared SwiftData schema.
- Derive the current roster from rules, completions, `now`, and an injected calendar.
- Cap the roster at two rules, select it before filtering current-day completions, and never replace a completed row on the same day.
- Keep routines out of `Quest`, `QuestSnapshot`, `DailyFocusState`, notifications, widgets, Hero derivation, graves, Hall of Fame, and App Intents.
- Use a native management sheet and title-only editor instead of extending the ordinary Quest editor.
- Preserve completion facts when a rule is deleted.

## File Plan

Create:

- `QuestKeeperShared/RoutineRule.swift` and `QuestKeeperShared/RoutineCompletion.swift` for the raw SwiftData facts and their snapshots.
- `QuestKeeper/Routines/RoutineState.swift` and `QuestKeeper/Routines/RoutineCompletionRecorder.swift` for pure selection and idempotent fact recording.
- `QuestKeeper/Views/RoutineSection.swift`, `QuestKeeper/Views/RoutineManagementSheet.swift`, and `QuestKeeper/Views/RoutineEditor.swift` for the narrow home and management surfaces.
- Focused routine state, recorder, and UI test files.

Modify:

- `QuestKeeperShared/QuestModelContainer.swift` to register the two new models.
- `QuestKeeper/ContentView.swift` to query rules and completions, derive the daily roster, route management, and record completion.
- `QuestKeeper/Views/HomeDungeonBoardView.swift` to place the routine section after ordinary and Daily Focus content.
- `QuestKeeperTests/QuestModelMigrationTests.swift` to prove previous Quest rows survive the schema addition.
- `QuestKeeper/Views/AppStrings.swift` and `QuestKeeper/Localizable.xcstrings` for Korean-default and English routine copy.

## Tasks

1. Add pure routine snapshots and state tests first.
   Make the tests fail before the derivation exists.
   Cover the fixed two-row roster, UUID ordering, day rotation, same-day completion hiding without replacement, next-day eligibility, and injected time-zone behavior.

2. Add the two SwiftData models and completion recorder.
   Record only one completion per routine and local day.
   Keep the recorder idempotent and save before the UI reflects the mutation.

3. Register the schema and extend the existing migration test.
   Prove a Quest-only on-disk store opens with all previous Quest facts unchanged.

4. Build the home section and management flow.
   Keep the routine row separate from `QuestRow` so it cannot show deadline, urgency, monster, or ordinary completion behavior.
   Use one local sheet route and no new navigation router.

5. Add localized UI tests.
   Exercise creation, completion removal, management after the roster is empty, deletion, and the unchanged Daily Focus entry surface.

6. Verify changed paths first, then run localization, focused unit and UI tests, the migration test, and one full unit-test regression.
   Read the populated and all-completed simulator screens before treating test output as visual proof.
