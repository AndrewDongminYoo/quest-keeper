# Tech Stack

- Swift 6.0, strict concurrency `complete` (all targets). Code must compile clean under Swift 6 strict concurrency (`Sendable`, actors, `async/await`).
- SwiftUI + SwiftData (`@Model`, `@Query`, `ModelContainer`).
- UserNotifications (`UNCalendarNotificationTrigger`).
- WidgetKit + App Groups (`TimelineProvider`, `TimelineView` for live countdown).
- No SPM/CocoaPods/workspace. Single `.xcodeproj`, no third-party deps (deliberate — building on Apple 1st-party stacks by hand is the learning goal; justify any new dep against that).

## Build config (project.pbxproj)

- `IPHONEOS_DEPLOYMENT_TARGET = 26.5` (iOS 26.5).
- `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"`, `TARGETED_DEVICE_FAMILY = 1` (iPhone-only; template macOS/visionOS support already removed).
- Bundle IDs: app `kr.donminzzi.QuestKeeper`, widget `kr.donminzzi.QuestKeeper.Widget`, tests `kr.donminzzi.QuestKeeperTests` / `.QuestKeeperUITests`.
- App Group: `group.kr.donminzzi.QuestKeeper` (in both app + widget entitlements; also `WidgetDungeonSnapshotStore.appGroupIdentifier`).

## Targets / schemes

Two shared schemes: `QuestKeeper` (app) and `QuestKeeperWidget`. Targets: app, widget extension, `QuestKeeperShared` (shared code), `QuestKeeperTests` (Swift Testing), `QuestKeeperUITests` (XCTest).
