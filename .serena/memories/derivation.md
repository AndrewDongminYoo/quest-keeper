# Derivation Layer

Pure, deterministic layer in `QuestKeeper/Derivation/`. All game state is computed here from facts + `now`; nothing is stored. This is where new gamification rules belong (see `mem:core` invariant).

- `QuestOutcome.swift` — `QuestOutcome` enum (per-quest derived status: active / completed / missed-daily-grave, etc.); `QuestSnapshot` namespace helpers.
- `HeroDerivation.swift` — `HeroDerivation` enum (namespace) producing `HeroState` struct: outcome, urgency, mob level, total victories, daily graves, reopen death events. Filters graves to the current daily window (24h) — misses outside the window are hidden by derivation, not deleted from DB. Does not count/accumulate graves.
- `GameBalance.swift` — `GameBalance` enum: tunable constants. `longQuestWarningHorizon` (7 days) gates the elder-guide chunking prompt in the quest editor. Mob level = `importance` (stored) × urgency (derived); urgency = f(time remaining until deadline).

Fact mutations (not derivation) live in `QuestKeeper/Actions/`:
- `QuestActions.retryDeadlineTomorrow` — "내일 도전하기": overwrites the `deadline` fact to tomorrow.
- `Activation.reconstructOnActivation` — scenePhase `.active` replay: reconstructs deaths between `lastOpened` and `now`.

Widget-side derivation is duplicated/shared in `QuestKeeperShared/WidgetDungeonDerivation.swift` so the widget renders derived state without the app running.

Tests: `DerivationTests`, `QuestActionsTests`, `QuestBattleResolutionTests`, `DungeonPresentationTests`.
