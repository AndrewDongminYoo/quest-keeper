# QuestKeeper — Core

Native iOS gamified to-do app (SwiftUI + SwiftData). Primary purpose is a native-iOS learning track (OS boundaries without a Flutter/RN bridge); the gamification is the vehicle. iPhone-only, local-only, offline-first, no backend/accounts/CloudKit.

Quest = task, deadline = monster, on-time completion = one-hit victory. Missed quests show as a today-only "daily grave" (never a permanent archive).

## Central invariant — "Persist facts only, derive state"

Architectural spine. Non-negotiable across all feature work.

- Persist ONLY raw immutable facts on `@Model Quest`: `id`, `title`, `deadline`, `completedAt?`, `importance`.
- NEVER store derived state (`hp`, `isDead`, `mobLevel`, `urgency`, grave/victory counts, `outcome`, retry counts, notification IDs, widget IDs, monster type, `lastNotificationFiredAt`, reminder flags) on a `@Model`. If tempted to store one, it belongs in a pure derivation function.
- Derive everything against the current time at read time.
- Deadline judgment is state replay, not event-driven: on reopen compare `lastOpened`/`now` vs each `deadline` to reconstruct which heroes should have died in between (`reconstructOnActivation` in `QuestKeeper/Actions/Activation.swift`).
- Derivation must be pure/deterministic (same inputs → same output).

## Source map

- `QuestKeeper/` — app target.
  - `Models/` — `Quest` (`@Model`) + `Importance` enum; `QuestSnapshot` value type.
  - `Derivation/` — pure derivation layer, see `mem:derivation`.
  - `Actions/` — fact mutations: `QuestActions.retryDeadlineTomorrow`, `Activation.reconstructOnActivation`.
  - `Views/` — SwiftUI dungeon UI; root is `HomeDungeonBoardView`, rows in `QuestRow`, battle transitions in `QuestBattleResolution`.
  - `Notifications/` — local notification lifecycle, see `mem:notifications`.
  - `WidgetSupport/` — app-side widget snapshot writer.
- `QuestKeeperShared/` — code shared app↔widget: `WidgetDungeonPayload` (Codable), `WidgetDungeonDerivation`, `WidgetDungeonSnapshotStore` (App Group JSON store).
- `QuestKeeperWidget/` — WidgetKit extension (read-only Home Screen dungeon, `systemSmall`/`systemMedium`).
- `QuestKeeperTests/` — Swift Testing coverage.
- `docs/specs/` — behavior contracts (source of truth); `docs/plans/` — implementation plans; `docs/notes/` — evidence logs/retros.

## Authoritative docs

`BLUEPRINT.md` owns product + learning roadmap (phases, success criteria). `DESIGN.md` owns visual/UX direction (pixel dungeon, color tokens, shame-free voice). `docs/specs/NNN-*.md` own per-phase contracts — read the relevant spec before feature work.

## Other memories

`mem:tech_stack`, `mem:conventions`, `mem:derivation`, `mem:notifications`, `mem:suggested_commands`, `mem:task_completion`.
