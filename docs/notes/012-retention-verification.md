# QuestKeeper Retention Verification

Verified on 2026-07-21 with the iPhone 17e simulator running iOS 26.5.
The app and widget builds used code commit `17d59f7` plus the uncommitted deterministic baseline note and equality test, which do not affect either product target.

## Automated Evidence

The focused measurement run passed 26 tests in 6 suites.
The complete scheme run passed 109 Swift Testing tests in 22 suites and the existing UI test suites.
The complete run reported `TEST SUCCEEDED`, but its result-bundle activity-log import then reported `No space left on device`.
The unavailable simulator cleanup increased free system volume space from 107 MiB to 1.0 GiB before the final app and widget builds.
The `QuestKeeper` and `QuestKeeperWidget` schemes both completed with `BUILD SUCCEEDED`.

## Manual Simulator Evidence

A fresh QuestKeeper install created `첫 가치 확인`, displayed it in the dungeon, and completed it through the app UI.
The hero summary changed from 승리 0 to 승리 1.
After a genuine Home-screen background and foreground transition, the app created `위젯 완료 확인`.
The QuestKeeper widget displayed that quest, completed it through the widget check control, refreshed to its empty state, and the foregrounded app displayed 승리 2.
The notification permission prompt was denied for this test, and the existing Korean settings banner appeared without blocking quest creation or completion.

The live `retention-baseline-v1.json` reported complete data quality, first value 1 / 1, first completion 1 / 1, weekly active installations 1, and weekly repeated completion 1 / 1.
Neither typed quest title appeared in the JSON.
The shared SwiftData store contained one installation and seven event rows with seven distinct deduplication keys: three app activations, two app quest creations, one app completion, and one widget completion.

## Limitation

The daily-grave retry UI was not manually completed because the simulator date-picker wheel exposed a settable accessibility element but did not accept the attempted value change.
No direct database mutation was used to manufacture that UI state.
The existing automated retry test passed and verifies that retry tomorrow moves the deadline forward, clears completion, and preserves importance.
