# Home Dungeon Board Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the default native home list with a SwiftUI dungeon board that improves quest visibility without changing stored facts or lifecycle behavior.

**Architecture:** Keep `ContentView` as the lifecycle and routing owner.
Move the visual home surface into a `HomeDungeonBoardView` shell that composes `HeroHeader`, `QuestListSections`, `QuestRow`, `DailyGraveRow`, and an empty board state.
Add pure presentation helpers only for countdown and urgency text that are worth testing.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Swift Testing, UserNotifications, WidgetKit, iOS Simulator `iPhone 17e`.

## Global Constraints

- Use `docs/{notes,plans,specs}` for project docs.
- Keep markdown prose sentence-per-line with no hard wraps.
- Keep Korean user-facing strings intentional.
- Preserve create, edit, complete, retry tomorrow, delete, notification sync, activation replay, and widget snapshot behavior.
- Do not add stored derived fields to `Quest`.
- Do not add third-party dependencies.
- Do not introduce SpriteKit, SceneKit, bitmap asset production, bottom tabs, or new gameplay mechanics.
- Validate with `xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests`.
- Validate with `xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'`.

---

## File Structure

- Create `QuestKeeper/Views/DungeonPresentation.swift`.
  This file contains pure nonisolated display helpers for countdown text and urgency tone.
- Create `QuestKeeperTests/DungeonPresentationTests.swift`.
  This file tests pure presentation behavior without SwiftUI rendering.
- Create `QuestKeeper/Views/HomeDungeonBoardView.swift`.
  This file owns the primary home screen shell, board background, HUD placement, empty state, and scroll container.
- Modify `QuestKeeper/ContentView.swift`.
  Replace the root `List` with `HomeDungeonBoardView` while preserving lifecycle callbacks and sheets.
- Modify `QuestKeeper/Views/QuestListSections.swift`.
  Replace native `Section` styling with board section labels and swipe-capable row composition.
- Modify `QuestKeeper/Views/QuestRow.swift`.
  Redesign pending and daily-grave rows as stable dungeon floor bands.

---

### Task 1: Presentation Helpers

**Files:**
- Create: `QuestKeeper/Views/DungeonPresentation.swift`
- Create: `QuestKeeperTests/DungeonPresentationTests.swift`

**Interfaces:**
- Produces: `nonisolated enum DungeonUrgencyTone: Equatable`
- Produces: `nonisolated enum DungeonPresentation`
- Produces: `DungeonPresentation.countdownText(deadline: Date, now: Date) -> String`
- Produces: `DungeonPresentation.urgencyTone(deadline: Date, mobLevel: Int, now: Date) -> DungeonUrgencyTone`
- Consumes: `Date`, `TimeInterval`, and derived `mobLevel` values.

- [ ] **Step 1: Write failing countdown tests**

Create `QuestKeeperTests/DungeonPresentationTests.swift`:

```swift
import Foundation
import Testing
@testable import QuestKeeper

struct DungeonPresentationTests {
    @Test("countdown text keeps days, hours, minutes, and past due readable")
    func countdownText() {
        let now = Date(timeIntervalSinceReferenceDate: 820_584_000)

        #expect(DungeonPresentation.countdownText(deadline: now.addingTimeInterval(2 * 24 * 60 * 60), now: now) == "2일 남음")
        #expect(DungeonPresentation.countdownText(deadline: now.addingTimeInterval(3 * 60 * 60 + 20 * 60), now: now) == "3시간 20분 남음")
        #expect(DungeonPresentation.countdownText(deadline: now.addingTimeInterval(15 * 60), now: now) == "15분 남음")
        #expect(DungeonPresentation.countdownText(deadline: now.addingTimeInterval(-60), now: now) == "마감 임박")
    }
}
```

- [ ] **Step 2: Run countdown tests to verify RED**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/DungeonPresentationTests -quiet
```

Expected: FAIL because `DungeonPresentation` does not exist.

- [ ] **Step 3: Add minimal countdown helper**

Create `QuestKeeper/Views/DungeonPresentation.swift`:

```swift
import Foundation

nonisolated enum DungeonUrgencyTone: Equatable {
    case calm
    case warning
    case danger
}

nonisolated enum DungeonPresentation {
    static func countdownText(deadline: Date, now: Date) -> String {
        let remaining = deadline.timeIntervalSince(now)
        guard remaining > 0 else { return "마감 임박" }

        let minutes = Int(remaining) / 60
        if minutes >= 1440 { return "\(minutes / 1440)일 남음" }
        if minutes >= 60 { return "\(minutes / 60)시간 \(minutes % 60)분 남음" }
        return "\(minutes)분 남음"
    }

    static func urgencyTone(deadline: Date, mobLevel: Int, now: Date) -> DungeonUrgencyTone {
        let remaining = deadline.timeIntervalSince(now)
        if remaining <= 60 * 60 || mobLevel >= 4 { return .danger }
        if remaining <= 6 * 60 * 60 || mobLevel >= 2 { return .warning }
        return .calm
    }
}
```

- [ ] **Step 4: Add urgency tests**

Append to `DungeonPresentationTests`:

```swift
    @Test("urgency tone escalates by deadline pressure and mob level")
    func urgencyTone() {
        let now = Date(timeIntervalSinceReferenceDate: 820_584_000)

        #expect(DungeonPresentation.urgencyTone(deadline: now.addingTimeInterval(2 * 24 * 60 * 60), mobLevel: 1, now: now) == .calm)
        #expect(DungeonPresentation.urgencyTone(deadline: now.addingTimeInterval(5 * 60 * 60), mobLevel: 1, now: now) == .warning)
        #expect(DungeonPresentation.urgencyTone(deadline: now.addingTimeInterval(2 * 24 * 60 * 60), mobLevel: 3, now: now) == .warning)
        #expect(DungeonPresentation.urgencyTone(deadline: now.addingTimeInterval(30 * 60), mobLevel: 1, now: now) == .danger)
        #expect(DungeonPresentation.urgencyTone(deadline: now.addingTimeInterval(2 * 24 * 60 * 60), mobLevel: 5, now: now) == .danger)
    }
```

- [ ] **Step 5: Run helper tests to verify GREEN**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/DungeonPresentationTests -quiet
```

Expected: PASS.

- [ ] **Step 6: Commit Task 1**

Run:

```bash
git add QuestKeeper/Views/DungeonPresentation.swift QuestKeeperTests/DungeonPresentationTests.swift
git commit -m "test(ui): cover dungeon row presentation helpers"
```

---

### Task 2: Home Board Shell

**Files:**
- Create: `QuestKeeper/Views/HomeDungeonBoardView.swift`
- Modify: `QuestKeeper/ContentView.swift`

**Interfaces:**
- Consumes: `HeroState`, `[Quest]`, `Date`, and existing `ContentView` callbacks.
- Produces: `HomeDungeonBoardView`, a SwiftUI view that replaces the root `List` surface.

- [ ] **Step 1: Create the board shell**

Create `QuestKeeper/Views/HomeDungeonBoardView.swift`:

```swift
import SwiftUI

struct HomeDungeonBoardView: View {
    let state: HeroState
    let isMourning: Bool
    let pending: [Quest]
    let dailyGraves: [Quest]
    let now: Date
    let showsNotificationPermissionBanner: Bool
    let onCreate: () -> Void
    let onOpenNotificationSettings: () -> Void
    let onComplete: (Quest) -> Void
    let onRetryTomorrow: (Quest) -> Void
    let onDelete: (Quest) -> Void
    let onEdit: (Quest) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            DungeonBackground()
            ScrollView {
                LazyVStack(spacing: 14) {
                    BoardHUD(state: state, isMourning: isMourning, onCreate: onCreate)
                    if showsNotificationPermissionBanner {
                        NotificationPermissionBanner(onOpenSettings: onOpenNotificationSettings)
                    }
                    if pending.isEmpty && dailyGraves.isEmpty {
                        EmptyDungeonState(onCreate: onCreate)
                    } else {
                        QuestListSections(
                            pending: pending,
                            dailyGraves: dailyGraves,
                            now: now,
                            onComplete: onComplete,
                            onRetryTomorrow: onRetryTomorrow,
                            onDelete: onDelete,
                            onEdit: onEdit
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
        }
        .background(Color(red: 0.09, green: 0.08, blue: 0.13))
    }
}
```

- [ ] **Step 2: Add board subviews**

Append to `HomeDungeonBoardView.swift`:

```swift
private struct DungeonBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.08, blue: 0.14),
                Color(red: 0.14, green: 0.13, blue: 0.19)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

private struct BoardHUD: View {
    let state: HeroState
    let isMourning: Bool
    let onCreate: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HeroHeader(state: state, isMourning: isMourning)
            Button(action: onCreate) {
                Image(systemName: "plus")
                    .font(.headline.weight(.bold))
                    .frame(width: 42, height: 42)
                    .background(Color(red: 0.24, green: 0.44, blue: 0.84), in: Circle())
                    .foregroundStyle(.white)
            }
            .accessibilityLabel("전투 추가")
        }
        .padding(16)
        .background(Color(red: 0.13, green: 0.11, blue: 0.18).opacity(0.92), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct EmptyDungeonState: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.35))
            Text("오늘의 던전이 비었습니다")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
            Text("작은 전투 하나를 추가해 시작하세요.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
            Button(action: onCreate) {
                Label("전투 추가", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(.horizontal, 18)
        .background(Color(red: 0.17, green: 0.16, blue: 0.22), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct NotificationPermissionBanner: View {
    let onOpenSettings: () -> Void

    var body: some View {
        Button(action: onOpenSettings) {
            Label("마감 알림을 받으려면 설정에서 QuestKeeper 알림을 켜세요.", systemImage: "bell.slash")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(red: 0.40, green: 0.16, blue: 0.14), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}
```

- [ ] **Step 3: Replace the root List callsite**

In `QuestKeeper/ContentView.swift`, replace the `List { ... }` block and its `.scrollContentBackground`, `.background`, `.overlay`, and `.listStyle` modifiers with:

```swift
HomeDungeonBoardView(
    state: state,
    isMourning: !pendingDeaths.isEmpty,
    pending: pending,
    dailyGraves: dailyGraves,
    now: now,
    showsNotificationPermissionBanner: notificationAuthorization == .denied,
    onCreate: { route = .create },
    onOpenNotificationSettings: openNotificationSettings,
    onComplete: complete,
    onRetryTomorrow: retryTomorrow,
    onDelete: delete,
    onEdit: { route = .edit($0) }
)
```

- [ ] **Step 4: Remove the old notification permission section**

Delete the old `notificationPermissionSection` property from `ContentView`.
`HomeDungeonBoardView` now owns the board-styled notification banner through `showsNotificationPermissionBanner` and `onOpenNotificationSettings`.

```swift
// Delete notificationPermissionSection.
```

- [ ] **Step 5: Remove duplicate toolbar add button**

Remove the `.toolbar` block from `ContentView`.
Keep `.navigationTitle`, `.toolbarBackground`, and `.toolbarColorScheme` only if they still compile and do not duplicate the HUD.

- [ ] **Step 6: Build after shell replacement**

Run:

```bash
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -quiet
```

Expected: build succeeds.

- [ ] **Step 7: Commit Task 2**

Run:

```bash
git add QuestKeeper/ContentView.swift QuestKeeper/Views/HomeDungeonBoardView.swift
git commit -m "feat(ui): add home dungeon board shell"
```

---

### Task 3: Dungeon Row Visuals

**Files:**
- Modify: `QuestKeeper/Views/QuestListSections.swift`
- Modify: `QuestKeeper/Views/QuestRow.swift`

**Interfaces:**
- Consumes: `DungeonPresentation.countdownText(deadline:now:)`
- Consumes: `DungeonPresentation.urgencyTone(deadline:mobLevel:now:)`
- Preserves: `QuestListSections` callbacks and swipe actions.

- [ ] **Step 1: Convert list sections into board groups**

Replace `QuestListSections.body` with:

```swift
var body: some View {
    VStack(alignment: .leading, spacing: 12) {
        if !pending.isEmpty {
            BoardSectionTitle(title: "던전", count: pending.count)
            VStack(spacing: 10) {
                ForEach(pending) { quest in
                    QuestRow(quest: quest, now: now)
                        .contentShape(Rectangle())
                        .onTapGesture { onEdit(quest) }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button { onComplete(quest) } label: {
                                Label("완료", systemImage: "checkmark")
                            }
                            .tint(.green)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { onDelete(quest) } label: {
                                Label("삭제", systemImage: "trash")
                            }
                        }
                }
            }
        }

        if !dailyGraves.isEmpty {
            BoardSectionTitle(title: "오늘의 무덤", count: dailyGraves.count)
            VStack(spacing: 10) {
                ForEach(dailyGraves) { quest in
                    DailyGraveRow(quest: quest) {
                        onRetryTomorrow(quest)
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Add board section title**

Append to `QuestListSections.swift`:

```swift
private struct BoardSectionTitle: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(.caption, design: .monospaced).weight(.black))
                .foregroundStyle(.white.opacity(0.82))
            Text("\(count)")
                .font(.caption2.monospacedDigit().weight(.bold))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.12), in: Capsule())
                .foregroundStyle(.white.opacity(0.72))
            Spacer()
        }
        .textCase(.uppercase)
    }
}
```

- [ ] **Step 3: Redesign pending quest row**

Replace `QuestRow.body` with a stable floor-band layout:

```swift
var body: some View {
    let level = quest.snapshot.mobLevel(at: now)
    let tone = DungeonPresentation.urgencyTone(deadline: quest.deadline, mobLevel: level, now: now)

    HStack(spacing: 12) {
        DungeonLaneMarker(tone: tone)
        VStack(alignment: .leading, spacing: 8) {
            Text(quest.title)
                .font(.body.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Text(DungeonPresentation.countdownText(deadline: quest.deadline, now: now))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(tone.tint)
                ImportancePip(importance: quest.importance)
            }
        }
        Spacer(minLength: 10)
        VStack(alignment: .trailing, spacing: 8) {
            MobLevelBadge(level: level)
            MonsterGlyph(level: level)
        }
    }
    .padding(14)
    .frame(minHeight: 92)
    .background(Color(red: 0.20, green: 0.20, blue: 0.27), in: RoundedRectangle(cornerRadius: 8))
    .overlay(
        RoundedRectangle(cornerRadius: 8)
            .stroke(tone.tint.opacity(0.38), lineWidth: 1)
    )
}
```

- [ ] **Step 4: Redesign daily grave row**

Replace `DailyGraveRow.body` with:

```swift
var body: some View {
    HStack(spacing: 12) {
        Image(systemName: "xmark.seal.fill")
            .font(.title2)
            .foregroundStyle(Color(red: 0.66, green: 0.67, blue: 0.66))
            .frame(width: 34)
        VStack(alignment: .leading, spacing: 6) {
            Text(quest.title)
                .font(.body.weight(.bold))
                .strikethrough()
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(2)
            Text("오늘의 무덤")
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(Color(red: 0.70, green: 0.72, blue: 0.71))
        }
        Spacer(minLength: 10)
        Button(action: onRetryTomorrow) {
            Label("내일 도전하기", systemImage: "arrow.uturn.forward")
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
    }
    .padding(14)
    .frame(minHeight: 92)
    .background(Color(red: 0.17, green: 0.17, blue: 0.22), in: RoundedRectangle(cornerRadius: 8))
    .overlay(
        RoundedRectangle(cornerRadius: 8)
            .stroke(Color(red: 0.55, green: 0.57, blue: 0.56).opacity(0.35), lineWidth: 1)
    )
}
```

- [ ] **Step 5: Add row support views and tone tint**

Append to `QuestRow.swift`:

```swift
private struct DungeonLaneMarker: View {
    let tone: DungeonUrgencyTone

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(tone.tint)
            .frame(width: 5, height: 58)
    }
}

private struct ImportancePip: View {
    let importance: Importance

    var body: some View {
        Text("IMP \(importance.rawValue)")
            .font(.caption2.weight(.black))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.10), in: Capsule())
            .foregroundStyle(.white.opacity(0.72))
    }
}

private extension DungeonUrgencyTone {
    var tint: Color {
        switch self {
        case .calm: Color(red: 0.46, green: 0.86, blue: 0.62)
        case .warning: Color(red: 1.0, green: 0.70, blue: 0.29)
        case .danger: Color(red: 1.0, green: 0.43, blue: 0.35)
        }
    }
}
```

- [ ] **Step 6: Remove the old countdown property**

Delete `QuestRow.countdown`.
All countdown text should now come from `DungeonPresentation.countdownText(deadline:now:)`.

- [ ] **Step 7: Build after row redesign**

Run:

```bash
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -quiet
```

Expected: build succeeds.

- [ ] **Step 8: Commit Task 3**

Run:

```bash
git add QuestKeeper/Views/QuestListSections.swift QuestKeeper/Views/QuestRow.swift
git commit -m "feat(ui): redesign quest rows as dungeon floors"
```

---

### Task 4: Final Verification And Manual Screenshot

**Files:**
- Modify only if validation exposes a real issue.

**Interfaces:**
- Consumes: all files touched in Tasks 1-3.
- Produces: review-ready branch.

- [ ] **Step 1: Run full unit tests**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests -quiet
```

Expected: PASS.

- [ ] **Step 2: Run simulator build**

Run:

```bash
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -quiet
```

Expected: build succeeds.

- [ ] **Step 3: Run source and whitespace guards**

Run:

```bash
git diff --check
! rg -n '^\s*(?:@\w+(?:\([^)]*\))?\s*)*(?:private|fileprivate|internal|public|package|open)?\s*(?:var|let)\s+(?:[Hh][Pp]|isDead|graveCount|retryCount|notificationID|isNotificationScheduled|widgetID|mobLevel|monsterType|urgency)\b' QuestKeeper/Models
```

Expected: both commands pass.

- [ ] **Step 4: Launch and inspect the screen**

Run:

```bash
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -quiet
```

Then install and launch through Xcode, XcodeBuildMCP, or Simulator UI.
Capture a screenshot and inspect that the first viewport is a dungeon board, not a default native list.

- [ ] **Step 5: Commit final fixes if needed**

If Task 4 reveals a narrow issue, commit it:

```bash
git add QuestKeeper QuestKeeperTests
git commit -m "fix(ui): finish home dungeon board polish"
```

If no fixes are needed, do not create an empty commit.

---

## Self-Review

Spec coverage:

- Root `List` replacement is covered by Task 2.
- Row visibility and dungeon floor treatment are covered by Task 3.
- Pure presentation helper tests are covered by Task 1.
- Existing lifecycle preservation is covered by keeping `ContentView` callbacks and running `QuestKeeperTests`.
- Source guard is covered by Task 4.

Placeholder scan:

- No placeholder tokens or unspecified test steps remain.

Type consistency:

- `DungeonUrgencyTone`, `DungeonPresentation.countdownText(deadline:now:)`, and `DungeonPresentation.urgencyTone(deadline:mobLevel:now:)` are defined before use.
- `HomeDungeonBoardView` receives the same callbacks currently passed to `QuestListSections`.
