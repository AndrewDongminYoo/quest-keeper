# Suggested Commands

Darwin (macOS) + Xcode. No package manager, no workspace. Day-to-day dev runs in Xcode; use `xcodebuild` for headless verification. Simulator name must match an installed device (`xcrun simctl list devices available`); docs standardize on `iPhone 17e`.

## Verify (normal dev — focused unit gate)

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests
```

## Build gate (target/signing wiring changes)

```bash
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'
```

## Single Swift Testing test

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -only-testing:QuestKeeperTests/DerivationTests/<testName>
```

## Persistence guardrail (must pass after any Models change)

```bash
! rg -n '(var|let) +(hp|isDead|mobLevel|urgency|victories|graves|outcome|retry|monster|notificationID|isNotificationScheduled|reminderEnabled|lastNotificationFiredAt|widgetID)' QuestKeeper/Models/
```

## Schemes

```bash
xcodebuild -list -project QuestKeeper.xcodeproj   # → QuestKeeper, QuestKeeperWidget
open QuestKeeper.xcodeproj
```

Note: `rg` (ripgrep) is the assumed search tool. Standard unix utils (`git`, `ls`, `grep`, `find`) behave normally on Darwin.
