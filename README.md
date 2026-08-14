# QuestKeeper

QuestKeeper is a native iOS gamified to-do app for celebrating small wins without turning missed tasks into permanent shame.
The app treats each task as a `Quest`, each deadline as a dungeon encounter, and each on-time completion as a one-hit victory.
Missed quests can appear as today's temporary grave, but old misses are hidden by derivation so the main dungeon resets emotionally.

The project is also a deliberate native iOS learning track.
It crosses the OS surfaces that are easy to avoid from Flutter or React Native: SwiftData persistence, app lifecycle replay, local notification scheduling, WidgetKit, App Groups, and Swift 6 strict concurrency.

## Current Status

- iPhone-only SwiftUI app target with Swift 6 strict concurrency enabled.
- SwiftData `Quest` model stores raw quest facts only: `id`, `title`, optional `details`, `deadline`, `completedAt`, and `importance`.
- Pure derivation layer computes outcome, urgency, mob level, total victories, daily graves, and reopen death events from facts plus `now`.
- Root app surface shows a dungeon-oriented quest list with a hero header, active quests, visible daily graves, completion, retry tomorrow, delete, and edit flows.
- Quest editor includes the elder guide prompt when a deadline is beyond the long-quest warning horizon.
- A background Create Quest App Shortcut creates quests without foregrounding the app, and every quest opens the common detail surface, which is read-only when editing is unavailable.
- Local notification lifecycle supports deterministic due-soon and deadline requests, remove-before-add sync, completion/delete cancellation, activation reconcile, and notification tap routing.
- WidgetKit target reads an App Group JSON snapshot and renders a Home Screen dungeon for `systemSmall` and `systemMedium`, with one-tap quest completion from the widget.
- Later work adds pixel art, a retention measurement stack, an onboarding experiment, the daily-focus loop, and a DEBUG recovery-loop prototype.
- Phase specs and implementation plans are tracked in `docs/specs/` and `docs/plans/`.

## Core Rules

- Persist facts, derive state.
- Do not store HP, `isDead`, grave counts, retry counts, notification IDs, widget IDs, monster type, urgency, mob level, or outcome on `Quest`.
- Keep the app local-only and offline-first.
- Keep notifications and widgets as side effects around stored facts, not as sources of truth.
- Prefer Apple first-party frameworks and avoid third-party dependencies for the MVP.
- Keep Korean user-facing copy intentional and shame-free.

```swift
@Model
final class Quest {
    var id: UUID
    var title: String
    var details: String?
    var deadline: Date
    var completedAt: Date?
    var importance: Importance
}
```

## Tech Stack

- Swift 6
- SwiftUI
- SwiftData
- Swift Testing
- UserNotifications
- WidgetKit
- App Groups

## Repository Map

- `QuestKeeper/` contains the app target: derivation, fact actions, SwiftUI views, notification integration, the app-side widget snapshot writer, and the daily-focus, onboarding, recovery, and measurement layers.
- `QuestKeeperShared/` contains everything both targets need: the `Quest` SwiftData model, App Group model container and store actor, the Codable widget payload and widget derivation, the snapshot store, pixel-art primitives, and the measurement models and reports.
- `QuestKeeperWidget/` contains the WidgetKit extension, timeline provider, widget views, and the one-tap completion App Intent.
- `QuestKeeperTests/` contains Swift Testing coverage for derivation, actions, notifications, widget payloads, snapshot storage, timeline policy, and the measurement and experiment stacks.
- `docs/specs/` contains phase contracts and source-of-truth design decisions.
- `docs/plans/` contains implementation plans for larger phase work.
- `DESIGN.md` owns visual and UX direction.
- `BLUEPRINT.md` owns the product and learning roadmap.

## Requirements

- macOS with Xcode installed.
- iOS Simulator runtime matching the project deployment target.
- An iPhone simulator for the documented verification commands. They target a UDID, not a name — resolve yours with `xcrun simctl list devices available` and substitute it.
- Apple Developer signing that supports `group.kr.donminzzi.QuestKeeper` when testing App Group behavior on device or signed simulator builds.

## Run

Open the Xcode project and run the app scheme:

```bash
open QuestKeeper.xcodeproj
```

In Xcode, select the `QuestKeeper` scheme and an iPhone simulator, then run.

The project also exposes a widget scheme:

```bash
xcodebuild -list -project QuestKeeper.xcodeproj
```

Expected schemes:

```plaintext
QuestKeeper
QuestKeeperWidget
```

## Verification

Use the focused unit-test gate for normal development:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,id=24B14321-156A-4BC4-97DC-0183AD675A8D' -only-testing:QuestKeeperTests
```

Use the build gate when target or signing wiring changes:

```bash
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,id=24B14321-156A-4BC4-97DC-0183AD675A8D'
```

Target the simulator by UDID, never by `name`: a name destination clones a fresh ephemeral simulator per run and wedges the runtime.
Simulator UDIDs are recreated over time, so confirm the id above with `xcrun simctl list devices available` before relying on it.

Use this guard when changing persistence — it must cover both paths, since `Quest` lives in `QuestKeeperShared/` and a guard pointed only at `QuestKeeper/Models/` scans no `@Model` at all:

```bash
! rg -n '(var|let) +(hp|isDead|mobLevel|urgency|victories|graves|outcome|retry|monster|notificationID|isNotificationScheduled|reminderEnabled|lastNotificationFiredAt|widgetID)' QuestKeeper/Models/ QuestKeeperShared/Quest.swift
```

## Manual QA

Check the app through the user-facing surface before calling a feature done:

1. Create a near-deadline quest with an optional description.
2. Confirm it appears as an active mob with a countdown and derived level.
3. Complete it and confirm the victory count updates.
4. Create or edit a far-future quest and confirm the elder guide appears.
5. Let a quest pass its deadline, reopen the app, and confirm today's daily grave appears.
6. Use `내일 도전하기` and confirm the quest returns to the active dungeon.
7. Add the QuestKeeper widget to the Home Screen and confirm pending mobs appear from the App Group snapshot.
8. Complete or retry a quest in the app and confirm the widget refreshes through WidgetKit.
9. Run Create Quest from Shortcuts while QuestKeeper is in the background and notification permission is undetermined, then confirm it creates the quest without foregrounding the app or showing a permission prompt.
10. Reactivate the app, open the shortcut-created quest, and confirm the common detail surface shows its description.

## Documentation Conventions

Project documentation uses soft-wrapped prose with one sentence per line.
Keep fenced code blocks labeled with a language identifier.
Use `docs/specs/` for behavior contracts, `docs/plans/` for implementation plans, and `docs/notes/` for evidence logs or retrospectives.

## Out of Scope for MVP

- CloudKit sync.
- Accounts, login, or backend services.
- SpriteKit combat engine.
- Complex recurring quests.
- LLM task splitting.
- Permanent graveyard or shame dashboard.
