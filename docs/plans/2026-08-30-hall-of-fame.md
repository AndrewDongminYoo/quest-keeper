# Hall of Fame Implementation Plan

## Goal

Implement Linear AND-112 as a derived view of current victories with no persistence change.

## Scope And Constraints

- Reuse `QuestSnapshot.outcome(at:)` so Hall of Fame membership matches the HUD total.
- Sort victory IDs in one pure `HallOfFameState` helper before resolving their current Quest titles in the view.
- Reuse the existing item-driven `HomeDungeonSheet` state instead of adding a router or Boolean flag.
- Keep the sheet read-only and use the existing trophy artwork and palette.
- Do not modify `Quest`, `QuestSnapshot`, SwiftData schemas, widget data, release workflows, or `project.pbxproj`.

## File Plan

Create:

- `QuestKeeper/Derivation/HallOfFameState.swift` and `QuestKeeperTests/HallOfFameStateTests.swift` for the pure selection and ordering rule.
- `QuestKeeper/Views/HallOfFameSheet.swift` for the localized populated and empty sheet states.
- `QuestKeeperUITests/HallOfFameUITests.swift` for the HUD entry, localized titles, empty state, and long-title layout.

Modify:

- `QuestKeeper/Views/HeroHeader.swift` to turn the victory stat into an accessible 44-point button.
- `QuestKeeper/Views/HomeDungeonBoardView.swift` to add the local sheet case and resolve the derived IDs to current Quests.
- `QuestKeeper/Views/AppStrings.swift` and `QuestKeeper/Localizable.xcstrings` for production and deterministic fixture copy.
- `QuestKeeper/Debug/DebugFixtureSeeder.swift` to add a dedicated in-memory Hall of Fame fixture without changing existing fixtures.

## Tasks

1. Write the pure-state tests first.
   They must fail before `HallOfFameState` exists, then prove only on-time completions are selected, newest wins sort first, ties stay deterministic, and current-fact removal changes the result.

2. Implement the pure helper and run its targeted test.
   It returns ordered IDs from `QuestSnapshot` values and stores nothing.

3. Add the sheet, HUD entry, local sheet route, and localized strings.
   Use the existing `HomeDungeonSheet` ownership and the header's negative-padding touch-target pattern.

4. Add the isolated debug fixture and UI tests.
   The fixture must contain at least two on-time completions, one long localized title, and no persisted test data.

5. Verify the exact changed paths first, then run localization, focused unit and UI tests, and one full unit-test regression.
   Read the resulting Korean and English simulator screens rather than treating catalog checks as layout proof.
