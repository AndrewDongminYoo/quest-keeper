# QuestKeeper

QuestKeeper is a native iOS gamified to-do app for celebrating small wins without turning missed tasks into permanent shame.
The app treats each task as a `Quest`, each deadline as a dungeon encounter, and each on-time completion as a one-hit victory.
Missed quests can appear as today's temporary grave, but old misses are hidden by derivation so the main dungeon resets emotionally.

The project is also a deliberate native iOS learning track.
It crosses the OS surfaces that are easy to avoid from Flutter or React Native: SwiftData persistence, app lifecycle replay, local notification scheduling, WidgetKit, App Groups, and Swift 6 strict concurrency.

## Current Status

- iPhone-only SwiftUI app target with Swift 6 strict concurrency enabled.
- SwiftData model stores raw quest facts only: `id`, `title`, `deadline`, `completedAt`, and `importance`.
- Pure derivation layer computes outcome, urgency, mob level, total victories, daily graves, and reopen death events from facts plus `now`.
- Root app surface shows a dungeon-oriented quest list with a hero header, active quests, visible daily graves, completion, retry tomorrow, delete, and edit flows.
- Quest editor includes the elder guide prompt when a deadline is beyond the long-quest warning horizon.
- Local notification lifecycle supports deterministic due-soon and deadline requests, remove-before-add sync, completion/delete cancellation, activation reconcile, and notification tap routing.
- WidgetKit target reads an App Group JSON snapshot and renders a read-only Home Screen dungeon for `systemSmall` and `systemMedium`.
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

- `QuestKeeper/` contains the app target, SwiftData model, SwiftUI views, fact actions, notification integration, and app-side widget snapshot writer.
- `QuestKeeperShared/` contains the shared Codable widget payload, widget derivation, and App Group snapshot store.
- `QuestKeeperWidget/` contains the WidgetKit extension, timeline provider, and widget views.
- `QuestKeeperTests/` contains Swift Testing coverage for derivation, actions, notifications, widget payloads, snapshot storage, and timeline policy.
- `docs/specs/` contains phase contracts and source-of-truth design decisions.
- `docs/plans/` contains implementation plans for larger phase work.
- `DESIGN.md` owns visual and UX direction.
- `BLUEPRINT.md` owns the product and learning roadmap.

## Requirements

- macOS with Xcode installed.
- iOS Simulator runtime matching the project deployment target.
- An `iPhone 17e` simulator for the documented verification commands, or another available iPhone simulator if you adjust the destination.
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
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests
```

Use the build gate when target or signing wiring changes:

```bash
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'
```

Use this guard when changing persistence:

```bash
! rg -n '(var|let) +(hp|isDead|mobLevel|urgency|victories|graves|outcome|retry|monster|notificationID|isNotificationScheduled|reminderEnabled|lastNotificationFiredAt|widgetID)' QuestKeeper/Models/
```

## Manual QA

Check the app through the user-facing surface before calling a feature done:

1. Create a near-deadline quest.
2. Confirm it appears as an active mob with a countdown and derived level.
3. Complete it and confirm the victory count updates.
4. Create or edit a far-future quest and confirm the elder guide appears.
5. Let a quest pass its deadline, reopen the app, and confirm today's daily grave appears.
6. Use `내일 도전하기` and confirm the quest returns to the active dungeon.
7. Add the QuestKeeper widget to the Home Screen and confirm pending mobs appear from the App Group snapshot.
8. Complete or retry a quest in the app and confirm the widget refreshes through WidgetKit.

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
- Interactive widget actions.
- Permanent graveyard or shame dashboard.
