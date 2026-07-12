# Feature Backlog — Candidate Next Steps

Working note capturing post-Phase-5 feature candidates.
`BLUEPRINT.md` owns the canonical roadmap and the 2차 backlog; this note expands specific candidates with their native-iOS learning boundary and product value so a next feature can be picked deliberately.

The selection lens is the project's real purpose: each feature should cross a **new OS boundary** (or deepen an existing one) without breaking the "persist facts, derive state" spine.
Deployment target is iOS 26.5, so App Intents, interactive WidgetKit, ActivityKit, and Control widgets are all available.

## Status

- **Selected / next:** Interactive Widget (App Intents).
- Everything else below is unstarted and unordered beyond the rough priority given.

## Candidates

### 1. Interactive Widget (App Intents) — selected

Today the widget renders the App Group snapshot read-only; `README.md` lists "Interactive widget actions" as out of scope for the MVP, so this is the natural next graduation.

- **New OS boundary:** the App Intents framework — `AppIntent`, WidgetKit `Button(intent:)`, writing raw facts back through the App Group / SwiftData store from the intent, then `WidgetCenter.reloadTimelines`.
- **Product value:** complete or retry-tomorrow a quest straight from the Home Screen without opening the app.
- **Fact-only guardrail:** the intent mutates only stored facts (`completedAt`, `deadline`) and lets the existing derivation recompute; no derived state is stored.
- **Adjacent learning:** App Shortcuts / Siri phrases reuse the same intents.

### 2. Live Activity / Dynamic Island (ActivityKit)

Surface the most urgent quest's countdown on the Lock Screen and Dynamic Island.

- **New OS boundary:** `ActivityKit` — `ActivityConfiguration`, local (push-less) updates, `Text(timerInterval:)`. Push-less keeps it offline-first.
- **Product value:** the derived urgency axis (`urgency = f(time remaining)`) becomes visible on a system surface without opening the app.
- **Fact-only guardrail:** the activity is a projection of the nearest-deadline fact; nothing new is persisted.

### 3. Hall of Fame (전리품 창고)

The BLUEPRINT 2차 backlog's first item — a gallery of completed "small wins."

- **New OS boundary:** a second navigation destination, `@Query` / `FetchDescriptor` filtering and sorting on `completedAt`, optionally Swift Charts for a weekly victory trend.
- **Product value:** completes the "celebrate small wins" thesis with positive reinforcement.
- **Fact-only guardrail:** accumulating **victories** (not failures) is explicitly allowed by BLUEPRINT (Total Victories); the daily dungeon still resets misses by derivation.

### 4. Notification Actions (UNNotificationAction)

Actionable deadline notifications with inline buttons.

- **Boundary deepened:** `UNNotificationCategory` / `UNNotificationAction` plus delegate handling on top of the existing notifications layer — the smallest-scoped item here.
- **Product value:** `완료` / `내일 도전하기` directly from the notification banner.
- **Fact-only guardrail:** the action routes through the existing fact-mutation path.

## Secondary tracks

- **Mob visual tiers (slime → skeleton → dragon):** resolves a BLUEPRINT open question and realizes the `DESIGN.md` monster mapping by rendering `mobLevel` as evolving sprites. More visual polish than OS boundary; pairs with replacing SF Symbol placeholders with real pixel art.
- **Accessibility & Reduce Motion pass:** audit Dynamic Type, VoiceOver, and the Reduce-Motion fallbacks `DESIGN.md` calls for. Quality track, not a new framework.

## Known limitations (deferred)

- **Editor open across a background→foreground swap (spec 009).** `QuestKeeperApp` recreates the `ModelContainer` on a real foreground-from-background so a warm `@Query` sees widget writes. If the edit sheet is open during that transition, its `Quest` belongs to the pre-swap container. `route` strongly retains that `Quest`, which keeps its old context/container alive, and both containers address the same App Group SQLite file — so an edit still persists correctly; the only cost is the new `@Query` may lag one foreground. Low severity (no crash, no data loss). If it ever surfaces, dismiss the editor on foreground-from-background — but gate it so it does **not** clear a notification-launched route (`ContentView`'s notification routing uses `initial: true`).

## Open questions carried from BLUEPRINT

- Mob-level normalization: how many visual tiers, and the `importance × urgency` → tier mapping.
- Retry-tomorrow: keep original importance, or apply a "deferred" weighting that nudges the mob's appearance.
