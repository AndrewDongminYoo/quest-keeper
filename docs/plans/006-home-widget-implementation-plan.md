# Home Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a WidgetKit Home Screen widget that reads an App Group JSON snapshot and renders today's QuestKeeper dungeon state without opening SwiftData from the widget.

**Architecture:** Keep `Quest` as app-owned SwiftData raw facts. Add a small shared widget DTO/derivation layer that compiles into both the app and widget targets, then have the app atomically write `widget-dungeon-snapshot.json` to the App Group after quest mutations. The widget timeline provider reads that file, derives an entry for the current timeline date, and renders compact small/medium dungeon layouts.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, WidgetKit, App Groups, Swift Testing, Xcode project synchronized groups, iOS Simulator `iPhone 17e`.

## Global Constraints

- Store only raw facts on `Quest`: `id`, `title`, `deadline`, `completedAt`, `importance`.
- Do not store HP, `isDead`, grave count, retry count, monster type, urgency, mob level, notification IDs, widget IDs, or notification scheduled state on `Quest`.
- Use App Group identifier `group.kr.donminzzi.QuestKeeper`.
- Use widget extension bundle identifier `kr.donminzzi.QuestKeeper.Widget`.
- The widget reads `widget-dungeon-snapshot.json`; it does not open SwiftData.
- App Group JSON is a cache; missing, corrupt, or unsupported data renders an empty widget state.
- Widget MVP supports `systemSmall` and `systemMedium` only.
- No third-party dependencies.
- Korean user-facing strings stay Korean.
- Use TDD for behavior changes: add failing Swift Testing coverage before production code.

---

## File Structure

- Create `QuestKeeperShared/WidgetDungeonPayload.swift`
  - Shared Codable DTOs for the App Group JSON snapshot.
- Create `QuestKeeperShared/WidgetDungeonDerivation.swift`
  - Shared pure derivation from payload to widget entry state.
- Create `QuestKeeperShared/WidgetDungeonSnapshotStore.swift`
  - Shared JSON read/write helper with injectable file URL and App Group URL resolution.
- Modify `QuestKeeper.xcodeproj/project.pbxproj`
  - Add `QuestKeeperShared` as a synchronized root group compiled by `QuestKeeper` and `QuestKeeperWidget`.
  - Add a `QuestKeeperWidget` extension target and embed it in the app.
  - Add entitlements paths for app and widget targets.
- Create `QuestKeeper/QuestKeeper.entitlements`
  - App Group entitlement for the app target.
- Create `QuestKeeperWidget/QuestKeeperWidget.entitlements`
  - App Group entitlement for the widget target.
- Create `QuestKeeperWidget/QuestKeeperWidgetBundle.swift`
  - Widget bundle entry point.
- Create `QuestKeeperWidget/QuestKeeperWidget.swift`
  - Widget configuration and timeline provider.
- Create `QuestKeeperWidget/WidgetDungeonView.swift`
  - Small and medium widget views.
- Modify `QuestKeeper/ContentView.swift`
  - Write snapshots after quest mutations and activation refresh.
- Modify `QuestKeeper/Views/QuestEditor.swift`
  - Write snapshots after create/edit saves.
- Create `QuestKeeperTests/WidgetDungeonPayloadTests.swift`
  - Payload round-trip and derivation tests.
- Create `QuestKeeperTests/WidgetDungeonSnapshotStoreTests.swift`
  - File read/write and corrupt-data tests.
- Create `QuestKeeperTests/WidgetTimelinePolicyTests.swift`
  - Timeline refresh-date selection tests.

---

### Task 1: Shared Widget Payload and Derivation

**Files:**
- Create: `QuestKeeperShared/WidgetDungeonPayload.swift`
- Create: `QuestKeeperShared/WidgetDungeonDerivation.swift`
- Create: `QuestKeeperTests/WidgetDungeonPayloadTests.swift`
- Modify: `QuestKeeper.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes:
  - Raw quest facts from app code: `id`, `title`, `deadline`, `completedAt`, `importance.rawValue`.
- Produces:
  - `WidgetDungeonPayload(schemaVersion:generatedAt:quests:)`
  - `WidgetQuestPayload(id:title:deadline:completedAt:importanceRawValue:)`
  - `WidgetDungeonEntryState(date:generatedAt:activeMobs:dailyGraves:totalVictories:isStale:)`
  - `WidgetDungeonDerivation.derive(payload:at:calendar:) -> WidgetDungeonEntryState`
  - `WidgetDungeonDerivation.nextRefreshDate(payload:after:calendar:) -> Date`

- [ ] **Step 1: Add the shared folder to the app/test build graph**

Create the directory:

```bash
mkdir -p QuestKeeperShared
```

Modify `QuestKeeper.xcodeproj/project.pbxproj` so `QuestKeeperShared` is a `PBXFileSystemSynchronizedRootGroup` and the `QuestKeeper` target includes it in `fileSystemSynchronizedGroups`.
Keep the existing synchronized group style; do not convert the project to old-style per-file build phases.

Verify the project still loads:

```bash
xcodebuild -list -project QuestKeeper.xcodeproj
```

Expected: `QuestKeeper`, `QuestKeeperTests`, and `QuestKeeperUITests` still appear.

- [ ] **Step 2: Write failing payload and derivation tests**

Create `QuestKeeperTests/WidgetDungeonPayloadTests.swift`:

```swift
import Foundation
import Testing
@testable import QuestKeeper

@Suite("Widget dungeon payload")
struct WidgetDungeonPayloadTests {
    private let now = Date(timeIntervalSinceReferenceDate: 820_454_400)
    private let hour: TimeInterval = 60 * 60
    private let day: TimeInterval = 24 * 60 * 60

    @Test("payload round trips raw widget facts")
    func payloadRoundTripsRawFacts() throws {
        let questID = UUID()
        let payload = WidgetDungeonPayload(
            schemaVersion: WidgetDungeonPayload.currentSchemaVersion,
            generatedAt: now,
            quests: [
                WidgetQuestPayload(
                    id: questID,
                    title: "물 마시기",
                    deadline: now.addingTimeInterval(hour),
                    completedAt: nil,
                    importanceRawValue: 2
                )
            ]
        )

        let data = try JSONEncoder.widgetDungeon.encode(payload)
        let decoded = try JSONDecoder.widgetDungeon.decode(WidgetDungeonPayload.self, from: data)

        #expect(decoded == payload)
    }

    @Test("derivation exposes active mobs, daily graves, and victories")
    func derivationBuildsWidgetState() {
        let activeID = UUID()
        let dailyGraveID = UUID()
        let oldGraveID = UUID()
        let victoryID = UUID()
        let payload = WidgetDungeonPayload(
            schemaVersion: WidgetDungeonPayload.currentSchemaVersion,
            generatedAt: now,
            quests: [
                WidgetQuestPayload(
                    id: activeID,
                    title: "리뷰하기",
                    deadline: now.addingTimeInterval(hour),
                    completedAt: nil,
                    importanceRawValue: 3
                ),
                WidgetQuestPayload(
                    id: dailyGraveID,
                    title: "아침 산책",
                    deadline: now.addingTimeInterval(-hour),
                    completedAt: nil,
                    importanceRawValue: 1
                ),
                WidgetQuestPayload(
                    id: oldGraveID,
                    title: "어제 운동",
                    deadline: now.addingTimeInterval(-day),
                    completedAt: nil,
                    importanceRawValue: 2
                ),
                WidgetQuestPayload(
                    id: victoryID,
                    title: "샤워하기",
                    deadline: now.addingTimeInterval(hour),
                    completedAt: now.addingTimeInterval(-hour),
                    importanceRawValue: 1
                )
            ]
        )

        let state = WidgetDungeonDerivation.derive(
            payload: payload,
            at: now,
            calendar: Calendar(identifier: .gregorian)
        )

        #expect(state.activeMobs.map(\.id) == [activeID])
        #expect(state.dailyGraves.map(\.id) == [dailyGraveID])
        #expect(state.totalVictories == 1)
        #expect(state.isStale == false)
    }

    @Test("active mobs are sorted by urgency and limited for widget families")
    func activeMobsAreSortedAndLimited() {
        let lateID = UUID()
        let soonID = UUID()
        let payload = WidgetDungeonPayload(
            schemaVersion: WidgetDungeonPayload.currentSchemaVersion,
            generatedAt: now,
            quests: [
                WidgetQuestPayload(id: lateID, title: "나중", deadline: now.addingTimeInterval(6 * hour), completedAt: nil, importanceRawValue: 3),
                WidgetQuestPayload(id: soonID, title: "곧", deadline: now.addingTimeInterval(30 * 60), completedAt: nil, importanceRawValue: 1)
            ]
        )

        let state = WidgetDungeonDerivation.derive(payload: payload, at: now)

        #expect(state.activeMobs.map(\.id) == [soonID, lateID])
        #expect(state.activeMobs.first?.mobLevel == 3)
    }
}
```

- [ ] **Step 3: Run tests to verify RED**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/WidgetDungeonPayloadTests
```

Expected: FAIL because `WidgetDungeonPayload`, `WidgetDungeonDerivation`, and `JSONEncoder.widgetDungeon` do not exist.

- [ ] **Step 4: Implement shared payload DTOs**

Create `QuestKeeperShared/WidgetDungeonPayload.swift`:

```swift
import Foundation

nonisolated struct WidgetDungeonPayload: Codable, Sendable, Equatable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let generatedAt: Date
    let quests: [WidgetQuestPayload]

    static let empty = WidgetDungeonPayload(
        schemaVersion: currentSchemaVersion,
        generatedAt: .distantPast,
        quests: []
    )
}

nonisolated struct WidgetQuestPayload: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let deadline: Date
    let completedAt: Date?
    let importanceRawValue: Int
}

nonisolated extension JSONEncoder {
    static var widgetDungeon: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

nonisolated extension JSONDecoder {
    static var widgetDungeon: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
```

- [ ] **Step 5: Implement shared derivation**

Create `QuestKeeperShared/WidgetDungeonDerivation.swift`:

```swift
import Foundation

nonisolated struct WidgetDungeonEntryState: Sendable, Equatable {
    let date: Date
    let generatedAt: Date
    let activeMobs: [WidgetMobState]
    let dailyGraves: [WidgetMobState]
    let totalVictories: Int
    let isStale: Bool

    static func empty(date: Date) -> WidgetDungeonEntryState {
        WidgetDungeonEntryState(
            date: date,
            generatedAt: .distantPast,
            activeMobs: [],
            dailyGraves: [],
            totalVictories: 0,
            isStale: true
        )
    }
}

nonisolated struct WidgetMobState: Sendable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let deadline: Date
    let importanceRawValue: Int
    let urgencyLevel: Int
    let mobLevel: Int
}

nonisolated enum WidgetDungeonDerivation {
    static let staleSnapshotAge: TimeInterval = 24 * 60 * 60
    static let fallbackRefreshInterval: TimeInterval = 15 * 60
    static let dueSoonLeadTime: TimeInterval = 60 * 60

    static func derive(
        payload: WidgetDungeonPayload,
        at date: Date,
        calendar: Calendar = .current
    ) -> WidgetDungeonEntryState {
        guard payload.schemaVersion == WidgetDungeonPayload.currentSchemaVersion else {
            return .empty(date: date)
        }

        var activeMobs: [WidgetMobState] = []
        var dailyGraves: [WidgetMobState] = []
        var totalVictories = 0

        for quest in payload.quests {
            if quest.completedAt != nil {
                totalVictories += 1
                continue
            }

            let mob = WidgetMobState(
                id: quest.id,
                title: quest.title,
                deadline: quest.deadline,
                importanceRawValue: quest.importanceRawValue,
                urgencyLevel: urgencyLevel(deadline: quest.deadline, at: date),
                mobLevel: max(1, quest.importanceRawValue) * urgencyLevel(deadline: quest.deadline, at: date)
            )

            if quest.deadline > date {
                activeMobs.append(mob)
            } else if calendar.isDate(quest.deadline, inSameDayAs: date) {
                dailyGraves.append(mob)
            }
        }

        activeMobs.sort { left, right in
            if left.deadline == right.deadline {
                return left.mobLevel > right.mobLevel
            }
            return left.deadline < right.deadline
        }

        dailyGraves.sort { left, right in
            left.deadline > right.deadline
        }

        return WidgetDungeonEntryState(
            date: date,
            generatedAt: payload.generatedAt,
            activeMobs: activeMobs,
            dailyGraves: dailyGraves,
            totalVictories: totalVictories,
            isStale: date.timeIntervalSince(payload.generatedAt) > staleSnapshotAge
        )
    }

    static func nextRefreshDate(
        payload: WidgetDungeonPayload,
        after date: Date,
        calendar: Calendar = .current
    ) -> Date {
        let thresholdDates = payload.quests
            .filter { $0.completedAt == nil && $0.deadline > date }
            .flatMap { quest in
                [
                    quest.deadline.addingTimeInterval(-dueSoonLeadTime),
                    quest.deadline
                ]
            }
            .filter { $0 > date }
            .sorted()

        return thresholdDates.first ?? date.addingTimeInterval(fallbackRefreshInterval)
    }

    private static func urgencyLevel(deadline: Date, at date: Date) -> Int {
        let remaining = deadline.timeIntervalSince(date)
        if remaining <= 0 { return 4 }
        if remaining <= 60 * 60 { return 3 }
        if remaining <= 6 * 60 * 60 { return 2 }
        return 1
    }
}
```

- [ ] **Step 6: Run tests to verify GREEN**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/WidgetDungeonPayloadTests
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add QuestKeeper.xcodeproj/project.pbxproj QuestKeeperShared QuestKeeperTests/WidgetDungeonPayloadTests.swift
git commit -m "feat: add widget dungeon payload derivation"
```

---

### Task 2: App Group Snapshot Store

**Files:**
- Create: `QuestKeeperShared/WidgetDungeonSnapshotStore.swift`
- Create: `QuestKeeperTests/WidgetDungeonSnapshotStoreTests.swift`

**Interfaces:**
- Consumes:
  - `WidgetDungeonPayload`
  - `JSONEncoder.widgetDungeon`
  - `JSONDecoder.widgetDungeon`
- Produces:
  - `WidgetDungeonSnapshotStore(appGroupIdentifier:fileManager:)`
  - `WidgetDungeonSnapshotStore(fileURL:fileManager:)`
  - `WidgetDungeonSnapshotStore.load() -> WidgetDungeonPayload`
  - `WidgetDungeonSnapshotStore.save(_:) throws`

- [ ] **Step 1: Write failing snapshot store tests**

Create `QuestKeeperTests/WidgetDungeonSnapshotStoreTests.swift`:

```swift
import Foundation
import Testing
@testable import QuestKeeper

@Suite("Widget dungeon snapshot store")
struct WidgetDungeonSnapshotStoreTests {
    private let now = Date(timeIntervalSinceReferenceDate: 820_454_400)

    @Test("store saves and loads payload atomically")
    func storeSavesAndLoadsPayload() throws {
        let directory = temporaryDirectory()
        let store = WidgetDungeonSnapshotStore(
            fileURL: directory.appending(path: "widget-dungeon-snapshot.json")
        )
        let payload = WidgetDungeonPayload(
            schemaVersion: WidgetDungeonPayload.currentSchemaVersion,
            generatedAt: now,
            quests: [
                WidgetQuestPayload(
                    id: UUID(),
                    title: "위젯 확인",
                    deadline: now.addingTimeInterval(600),
                    completedAt: nil,
                    importanceRawValue: 2
                )
            ]
        )

        try store.save(payload)

        #expect(store.load() == payload)
    }

    @Test("store returns empty payload for missing file")
    func storeReturnsEmptyPayloadForMissingFile() {
        let directory = temporaryDirectory()
        let store = WidgetDungeonSnapshotStore(
            fileURL: directory.appending(path: "missing.json")
        )

        #expect(store.load() == .empty)
    }

    @Test("store returns empty payload for corrupt file")
    func storeReturnsEmptyPayloadForCorruptFile() throws {
        let directory = temporaryDirectory()
        let fileURL = directory.appending(path: "widget-dungeon-snapshot.json")
        try Data("not-json".utf8).write(to: fileURL)
        let store = WidgetDungeonSnapshotStore(fileURL: fileURL)

        #expect(store.load() == .empty)
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "QuestKeeper-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
```

- [ ] **Step 2: Run tests to verify RED**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/WidgetDungeonSnapshotStoreTests
```

Expected: FAIL because `WidgetDungeonSnapshotStore` does not exist.

- [ ] **Step 3: Implement the snapshot store**

Create `QuestKeeperShared/WidgetDungeonSnapshotStore.swift`:

```swift
import Foundation
import os

nonisolated struct WidgetDungeonSnapshotStore: Sendable {
    static let appGroupIdentifier = "group.kr.donminzzi.QuestKeeper"
    static let fileName = "widget-dungeon-snapshot.json"

    private let fileURL: URL?

    init(
        appGroupIdentifier: String = Self.appGroupIdentifier,
        fileManager: FileManager = .default
    ) {
        fileURL = fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appending(path: Self.fileName)
    }

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func load() -> WidgetDungeonPayload {
        guard let fileURL else { return .empty }

        do {
            let data = try Data(contentsOf: fileURL)
            let payload = try JSONDecoder.widgetDungeon.decode(WidgetDungeonPayload.self, from: data)
            guard payload.schemaVersion == WidgetDungeonPayload.currentSchemaVersion else {
                return .empty
            }
            return payload
        } catch {
            return .empty
        }
    }

    func save(_ payload: WidgetDungeonPayload) throws {
        guard let fileURL else { return }

        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let temporaryURL = directoryURL.appending(path: ".\(Self.fileName).tmp-\(UUID().uuidString)")
        let data = try JSONEncoder.widgetDungeon.encode(payload)
        try data.write(to: temporaryURL, options: [.atomic])

        if FileManager.default.fileExists(atPath: fileURL.path) {
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temporaryURL)
        } else {
            try FileManager.default.moveItem(at: temporaryURL, to: fileURL)
        }
    }
}
```

- [ ] **Step 4: Run tests to verify GREEN**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/WidgetDungeonSnapshotStoreTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add QuestKeeperShared/WidgetDungeonSnapshotStore.swift QuestKeeperTests/WidgetDungeonSnapshotStoreTests.swift
git commit -m "feat: add widget snapshot store"
```

---

### Task 3: App Snapshot Writing

**Files:**
- Modify: `QuestKeeper/ContentView.swift`
- Modify: `QuestKeeper/Views/QuestEditor.swift`
- Test: `QuestKeeperTests/WidgetDungeonPayloadTests.swift`

**Interfaces:**
- Consumes:
  - `Quest.snapshot`
  - `Quest.title`
  - `WidgetDungeonSnapshotStore.save(_:)`
- Produces:
  - `WidgetDungeonPayload.make(from:generatedAt:) -> WidgetDungeonPayload`
  - App mutation hooks that call `writeWidgetSnapshot()`

- [ ] **Step 1: Add a failing app payload factory test**

Append this test to `QuestKeeperTests/WidgetDungeonPayloadTests.swift`:

```swift
@Test("payload factory preserves quest titles and raw facts")
@MainActor
func payloadFactoryPreservesRawFacts() throws {
    let quest = Quest(
        id: UUID(),
        title: "홈 위젯 만들기",
        deadline: now.addingTimeInterval(hour),
        importance: .high,
        completedAt: nil
    )

    let payload = WidgetDungeonPayload.make(from: [quest], generatedAt: now)

    #expect(payload.schemaVersion == WidgetDungeonPayload.currentSchemaVersion)
    #expect(payload.generatedAt == now)
    #expect(payload.quests == [
        WidgetQuestPayload(
            id: quest.id,
            title: "홈 위젯 만들기",
            deadline: quest.deadline,
            completedAt: nil,
            importanceRawValue: Importance.high.rawValue
        )
    ])
}
```

- [ ] **Step 2: Run test to verify RED**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/WidgetDungeonPayloadTests/payloadFactoryPreservesRawFacts
```

Expected: FAIL because `WidgetDungeonPayload.make(from:generatedAt:)` does not exist.

- [ ] **Step 3: Implement the app-only factory**

Create `QuestKeeper/WidgetSupport/WidgetDungeonPayload+Quest.swift`:

```swift
import Foundation

extension WidgetDungeonPayload {
    @MainActor
    static func make(from quests: [Quest], generatedAt: Date = .now) -> WidgetDungeonPayload {
        WidgetDungeonPayload(
            schemaVersion: currentSchemaVersion,
            generatedAt: generatedAt,
            quests: quests.map { quest in
                WidgetQuestPayload(
                    id: quest.id,
                    title: quest.title,
                    deadline: quest.deadline,
                    completedAt: quest.completedAt,
                    importanceRawValue: quest.importance.rawValue
                )
            }
        )
    }
}
```

- [ ] **Step 4: Run factory test to verify GREEN**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/WidgetDungeonPayloadTests/payloadFactoryPreservesRawFacts
```

Expected: PASS.

- [ ] **Step 5: Wire snapshot writes in app flows**

In `QuestKeeper/ContentView.swift`, add a local store property:

```swift
private let widgetSnapshotStore: WidgetDungeonSnapshotStore
```

Extend the initializer:

```swift
init(
    notificationService: QuestNotificationService = .shared,
    notificationRouteStore: NotificationRouteStore = NotificationRouteStore(),
    widgetSnapshotStore: WidgetDungeonSnapshotStore = WidgetDungeonSnapshotStore()
) {
    self.notificationService = notificationService
    self.notificationRouteStore = notificationRouteStore
    self.widgetSnapshotStore = widgetSnapshotStore
}
```

Add the helper in `ContentView`:

```swift
private func writeWidgetSnapshot() {
    let payload = WidgetDungeonPayload.make(from: quests)
    do {
        try widgetSnapshotStore.save(payload)
        WidgetCenter.shared.reloadAllTimelines()
    } catch {
        print("Failed to write widget snapshot: \(error.localizedDescription)")
    }
}
```

Add `import WidgetKit` to `ContentView.swift`.
Call `writeWidgetSnapshot()` after each successful mutation in:

- `complete(_:)`
- `retryTomorrow(_:)`
- `delete(_:)`
- activation `.active` refresh after notification reconcile

In `QuestKeeper/Views/QuestEditor.swift`, add an `onSaved` closure from `ContentView` so `QuestEditor` does not become responsible for global app state:

```swift
let onSaved: () -> Void
```

Call it only after the model mutation succeeds:

```swift
onSaved()
```

Pass `writeWidgetSnapshot` from `ContentView` when constructing the editor.

- [ ] **Step 6: Build to verify wiring**

Run:

```bash
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 7: Commit**

```bash
git add QuestKeeper/ContentView.swift QuestKeeper/Views/QuestEditor.swift QuestKeeper/WidgetSupport/WidgetDungeonPayload+Quest.swift QuestKeeperTests/WidgetDungeonPayloadTests.swift
git commit -m "feat: write widget snapshots from quest mutations"
```

---

### Task 4: Widget Target and App Group Entitlements

**Files:**
- Modify: `QuestKeeper.xcodeproj/project.pbxproj`
- Create: `QuestKeeper/QuestKeeper.entitlements`
- Create: `QuestKeeperWidget/QuestKeeperWidget.entitlements`
- Create: `QuestKeeperWidget/QuestKeeperWidgetBundle.swift`
- Create: `QuestKeeperWidget/QuestKeeperWidget.swift`
- Create: `QuestKeeperWidget/WidgetDungeonView.swift`

**Interfaces:**
- Consumes:
  - `QuestKeeperShared` files from Tasks 1 and 2.
- Produces:
  - `QuestKeeperWidget` extension target.
  - Embedded widget extension in the app product.
  - App Group entitlement on both app and widget targets.

- [ ] **Step 1: Create widget target files**

Create the directory:

```bash
mkdir -p QuestKeeperWidget
```

Create `QuestKeeper/QuestKeeper.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.kr.donminzzi.QuestKeeper</string>
	</array>
</dict>
</plist>
```

Create `QuestKeeperWidget/QuestKeeperWidget.entitlements` with the same App Group entry.

Create temporary compiling widget files:

`QuestKeeperWidget/QuestKeeperWidgetBundle.swift`

```swift
import WidgetKit
import SwiftUI

@main
struct QuestKeeperWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuestKeeperWidget()
    }
}
```

`QuestKeeperWidget/QuestKeeperWidget.swift`

```swift
import WidgetKit
import SwiftUI

struct QuestKeeperWidgetEntry: TimelineEntry {
    let date: Date
    let state: WidgetDungeonEntryState
}

struct QuestKeeperWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuestKeeperWidgetEntry {
        QuestKeeperWidgetEntry(date: .now, state: .empty(date: .now))
    }

    func getSnapshot(in context: Context, completion: @escaping (QuestKeeperWidgetEntry) -> Void) {
        let date = Date()
        completion(QuestKeeperWidgetEntry(date: date, state: .empty(date: date)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuestKeeperWidgetEntry>) -> Void) {
        let date = Date()
        let entry = QuestKeeperWidgetEntry(date: date, state: .empty(date: date))
        completion(Timeline(entries: [entry], policy: .after(date.addingTimeInterval(15 * 60))))
    }
}

struct QuestKeeperWidget: Widget {
    let kind = "QuestKeeperWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuestKeeperWidgetProvider()) { entry in
            WidgetDungeonView(entry: entry)
        }
        .configurationDisplayName("Quest Keeper")
        .description("오늘의 던전을 홈 화면에서 확인합니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
```

`QuestKeeperWidget/WidgetDungeonView.swift`

```swift
import SwiftUI
import WidgetKit

struct WidgetDungeonView: View {
    let entry: QuestKeeperWidgetEntry

    var body: some View {
        Text("QUEST KEEPER")
            .font(.caption.bold())
            .containerBackground(.black, for: .widget)
    }
}
```

- [ ] **Step 2: Add the extension target to the Xcode project**

Modify `QuestKeeper.xcodeproj/project.pbxproj` using the existing synchronized root group style:

- add a `PBXFileSystemSynchronizedRootGroup` for `QuestKeeperWidget`;
- add a `PBXNativeTarget` named `QuestKeeperWidget` with product type `com.apple.product-type.app-extension`;
- add `QuestKeeperWidget` and `QuestKeeperShared` to the widget target's `fileSystemSynchronizedGroups`;
- add `QuestKeeperWidget.appex` to Products;
- add an app `PBXCopyFilesBuildPhase` with `dstSubfolderSpec = 13` to embed the extension;
- add a target dependency from `QuestKeeper` to `QuestKeeperWidget`;
- set app build setting `CODE_SIGN_ENTITLEMENTS = QuestKeeper/QuestKeeper.entitlements`;
- set widget build setting `CODE_SIGN_ENTITLEMENTS = QuestKeeperWidget/QuestKeeperWidget.entitlements`;
- set widget build setting `PRODUCT_BUNDLE_IDENTIFIER = kr.donminzzi.QuestKeeper.Widget`;
- set widget build setting `GENERATE_INFOPLIST_FILE = YES`;
- set widget build setting `INFOPLIST_KEY_NSExtension_NSExtensionPointIdentifier = "com.apple.widgetkit-extension"`;
- set widget build setting `SKIP_INSTALL = YES`.

Keep `IPHONEOS_DEPLOYMENT_TARGET`, Swift version, and concurrency settings aligned with the app target.

- [ ] **Step 3: Verify target discovery**

Run:

```bash
xcodebuild -list -project QuestKeeper.xcodeproj
```

Expected: `QuestKeeperWidget` appears under targets. The app scheme may remain `QuestKeeper`.

- [ ] **Step 4: Build the app with embedded widget**

Run:

```bash
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'
```

Expected: BUILD SUCCEEDED and the app product embeds `QuestKeeperWidget.appex`.

- [ ] **Step 5: Commit**

```bash
git add QuestKeeper.xcodeproj/project.pbxproj QuestKeeper/QuestKeeper.entitlements QuestKeeperWidget
git commit -m "feat: add QuestKeeper widget target"
```

---

### Task 5: Widget Timeline Provider

**Files:**
- Modify: `QuestKeeperWidget/QuestKeeperWidget.swift`
- Create: `QuestKeeperTests/WidgetTimelinePolicyTests.swift`

**Interfaces:**
- Consumes:
  - `WidgetDungeonSnapshotStore.load()`
  - `WidgetDungeonDerivation.derive(payload:at:calendar:)`
  - `WidgetDungeonDerivation.nextRefreshDate(payload:after:calendar:)`
- Produces:
  - `QuestKeeperWidgetProvider(store:calendar:)`
  - Timeline entries based on the App Group payload.

- [ ] **Step 1: Write failing timeline policy tests**

Create `QuestKeeperTests/WidgetTimelinePolicyTests.swift`:

```swift
import Foundation
import Testing
@testable import QuestKeeper

@Suite("Widget timeline policy")
struct WidgetTimelinePolicyTests {
    private let now = Date(timeIntervalSinceReferenceDate: 820_454_400)

    @Test("next refresh uses the next due soon threshold")
    func nextRefreshUsesDueSoonThreshold() {
        let deadline = now.addingTimeInterval(3 * 60 * 60)
        let payload = WidgetDungeonPayload(
            schemaVersion: WidgetDungeonPayload.currentSchemaVersion,
            generatedAt: now,
            quests: [
                WidgetQuestPayload(
                    id: UUID(),
                    title: "긴급도 확인",
                    deadline: deadline,
                    completedAt: nil,
                    importanceRawValue: 2
                )
            ]
        )

        let refresh = WidgetDungeonDerivation.nextRefreshDate(payload: payload, after: now)

        #expect(refresh == deadline.addingTimeInterval(-WidgetDungeonDerivation.dueSoonLeadTime))
    }

    @Test("next refresh falls back when no pending quest exists")
    func nextRefreshFallsBackWhenNoPendingQuestExists() {
        let payload = WidgetDungeonPayload(
            schemaVersion: WidgetDungeonPayload.currentSchemaVersion,
            generatedAt: now,
            quests: []
        )

        let refresh = WidgetDungeonDerivation.nextRefreshDate(payload: payload, after: now)

        #expect(refresh == now.addingTimeInterval(WidgetDungeonDerivation.fallbackRefreshInterval))
    }
}
```

- [ ] **Step 2: Run tests to lock timeline policy**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/WidgetTimelinePolicyTests
```

Expected: PASS. If this fails, fix `WidgetDungeonDerivation.nextRefreshDate(payload:after:calendar:)` before wiring the provider.

- [ ] **Step 3: Replace the placeholder provider with App Group reading**

Update `QuestKeeperWidget/QuestKeeperWidget.swift`:

```swift
import WidgetKit
import SwiftUI

struct QuestKeeperWidgetEntry: TimelineEntry {
    let date: Date
    let state: WidgetDungeonEntryState
}

struct QuestKeeperWidgetProvider: TimelineProvider {
    private let store: WidgetDungeonSnapshotStore
    private let calendar: Calendar

    init(
        store: WidgetDungeonSnapshotStore = WidgetDungeonSnapshotStore(),
        calendar: Calendar = .current
    ) {
        self.store = store
        self.calendar = calendar
    }

    func placeholder(in context: Context) -> QuestKeeperWidgetEntry {
        let payload = WidgetDungeonPayload(
            schemaVersion: WidgetDungeonPayload.currentSchemaVersion,
            generatedAt: .now,
            quests: [
                WidgetQuestPayload(
                    id: UUID(),
                    title: "물 마시기",
                    deadline: .now.addingTimeInterval(45 * 60),
                    completedAt: nil,
                    importanceRawValue: 2
                )
            ]
        )
        let state = WidgetDungeonDerivation.derive(payload: payload, at: .now, calendar: calendar)
        return QuestKeeperWidgetEntry(date: .now, state: state)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuestKeeperWidgetEntry) -> Void) {
        let date = Date()
        let payload = context.isPreview ? placeholderPayload(date: date) : store.load()
        let state = WidgetDungeonDerivation.derive(payload: payload, at: date, calendar: calendar)
        completion(QuestKeeperWidgetEntry(date: date, state: state))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuestKeeperWidgetEntry>) -> Void) {
        let date = Date()
        let payload = store.load()
        let state = WidgetDungeonDerivation.derive(payload: payload, at: date, calendar: calendar)
        let entry = QuestKeeperWidgetEntry(date: date, state: state)
        let refreshDate = WidgetDungeonDerivation.nextRefreshDate(payload: payload, after: date, calendar: calendar)

        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private func placeholderPayload(date: Date) -> WidgetDungeonPayload {
        WidgetDungeonPayload(
            schemaVersion: WidgetDungeonPayload.currentSchemaVersion,
            generatedAt: date,
            quests: [
                WidgetQuestPayload(
                    id: UUID(),
                    title: "물 마시기",
                    deadline: date.addingTimeInterval(45 * 60),
                    completedAt: nil,
                    importanceRawValue: 2
                ),
                WidgetQuestPayload(
                    id: UUID(),
                    title: "푸시업 하나",
                    deadline: date.addingTimeInterval(3 * 60 * 60),
                    completedAt: date.addingTimeInterval(-60),
                    importanceRawValue: 1
                )
            ]
        )
    }
}

struct QuestKeeperWidget: Widget {
    let kind = "QuestKeeperWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuestKeeperWidgetProvider()) { entry in
            WidgetDungeonView(entry: entry)
        }
        .configurationDisplayName("Quest Keeper")
        .description("오늘의 던전을 홈 화면에서 확인합니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
```

- [ ] **Step 4: Run widget build**

Run:

```bash
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add QuestKeeperWidget/QuestKeeperWidget.swift QuestKeeperTests/WidgetTimelinePolicyTests.swift
git commit -m "feat: load widget timelines from app group snapshots"
```

---

### Task 6: Widget Dungeon UI

**Files:**
- Modify: `QuestKeeperWidget/WidgetDungeonView.swift`

**Interfaces:**
- Consumes:
  - `QuestKeeperWidgetEntry.state`
  - `WidgetDungeonEntryState.activeMobs`
  - `WidgetDungeonEntryState.dailyGraves`
  - `WidgetDungeonEntryState.totalVictories`
- Produces:
  - Small widget layout with the most urgent active mob.
  - Medium widget layout with up to three active mobs and safe empty/stale states.

- [ ] **Step 1: Replace placeholder view with family-aware layout**

Update `QuestKeeperWidget/WidgetDungeonView.swift`:

```swift
import SwiftUI
import WidgetKit

struct WidgetDungeonView: View {
    @Environment(\.widgetFamily) private var family

    let entry: QuestKeeperWidgetEntry

    var body: some View {
        ZStack {
            DungeonBackdrop()

            switch family {
            case .systemSmall:
                small
            default:
                medium
            }
        }
        .containerBackground(.black, for: .widget)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if let mob = entry.state.activeMobs.first {
                MobBadge(mob: mob, compact: true)
            } else {
                emptyState
            }

            Spacer(minLength: 0)
        }
        .padding(12)
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                header
                emptyOrStaleLine
                Spacer(minLength: 0)
            }
            .frame(width: 92, alignment: .leading)

            VStack(spacing: 6) {
                let mobs = Array(entry.state.activeMobs.prefix(3))
                if mobs.isEmpty {
                    emptyState
                } else {
                    ForEach(mobs) { mob in
                        MobBadge(mob: mob, compact: false)
                    }
                }
            }
        }
        .padding(12)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("QUEST")
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
            Text("VICTORIES \(entry.state.totalVictories)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.yellow)
        }
    }

    private var emptyOrStaleLine: some View {
        Group {
            if entry.state.isStale {
                Text("앱을 열면 갱신됩니다")
            } else if entry.state.activeMobs.isEmpty {
                Text("던전이 조용합니다")
            }
        }
        .font(.system(size: 10, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white.opacity(0.76))
        .lineLimit(2)
        .minimumScaleFactor(0.8)
    }

    private var emptyState: some View {
        Text(entry.state.isStale ? "앱을 열면 던전이 갱신됩니다" : "던전이 조용합니다")
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.82))
            .lineLimit(3)
            .minimumScaleFactor(0.75)
    }
}

private struct MobBadge: View {
    let mob: WidgetMobState
    let compact: Bool

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: compact ? 28 : 24, height: compact ? 28 : 24)
                Text("\(mob.mobLevel)")
                    .font(.system(size: compact ? 13 : 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.black)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(mob.title)
                    .font(.system(size: compact ? 12 : 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(compact ? 2 : 1)
                    .minimumScaleFactor(0.75)

                Text(mob.deadline, style: .relative)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.red.opacity(0.9))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, compact ? 7 : 5)
        .padding(.horizontal, 8)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 4))
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
    }

    private var color: Color {
        if mob.mobLevel >= 9 { return .red }
        if mob.mobLevel >= 5 { return .orange }
        return .green
    }
}

private struct DungeonBackdrop: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.08, blue: 0.13),
                Color(red: 0.18, green: 0.18, blue: 0.24)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.black.opacity(0.22))
                .frame(height: 18)
        }
    }
}
```

- [ ] **Step 2: Build widget UI**

Run:

```bash
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add QuestKeeperWidget/WidgetDungeonView.swift
git commit -m "feat: render quest keeper widget dungeon"
```

---

### Task 7: Final Verification

**Files:**
- Inspect only changed files from Tasks 1-6.

**Interfaces:**
- Consumes all previous task outputs.
- Produces verified Phase 4 baseline ready for PR.

- [ ] **Step 1: Run all unit tests**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests
```

Expected: all QuestKeeper unit tests pass.

- [ ] **Step 2: Build app and widget**

Run:

```bash
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Run source guards**

Run:

```bash
rg -n "isDead|graveCount|retryCount|notificationID|isNotificationScheduled|widgetID|mobLevel" QuestKeeper/Models QuestKeeperShared QuestKeeperWidget
```

Expected: no matches in `QuestKeeper/Models`; matches in `QuestKeeperShared` and `QuestKeeperWidget` are allowed only for derived widget display types, not persisted SwiftData models.

- [ ] **Step 4: Verify changed files and commits**

Run:

```bash
git status --short
git log --oneline --decorate -7
```

Expected: working tree is clean after the final commit, and commits are grouped by payload/derivation, snapshot store, app writer, widget target, provider, and UI.

- [ ] **Step 5: Manual widget smoke test**

Run the app, add the widget, and verify:

```plaintext
1. Create a pending quest with a near deadline.
2. Confirm the widget shows it as an active mob.
3. Complete the quest in the app.
4. Confirm the widget reloads and the victory count increments.
5. Create a quest, move it past due or wait until due.
6. Confirm today's missed quest can show as a daily grave and old missed quests are hidden.
```

- [ ] **Step 6: Final commit only if Task 7 changed files**

If Task 7 required small fixes, commit them:

```bash
git add <fixed-files>
git commit -m "fix: tighten widget phase verification"
```

If Task 7 changed no files, do not create an empty commit.
