# Changelog

All notable changes to TODO Slayer will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.0] - 2026-08-15

### Added

- Use the app in English, with every screen, notification, and widget localized alongside Korean.
- Create a quest from iOS Shortcuts and Siri without opening the app, including its description, deadline, and importance.
- Give a quest an optional description and read it on a new quest detail screen opened from any row or notification.
- Learn why a quest's monster looks the way it does by tapping its sprite, and see which monsters grew while the app was closed.

### Changed

- Removed the active-quest counter from the dungeon header so the board leads with the hero's record.

### Fixed

- Offered a way back to notification permission from inside the app after it was denied.
- Kept the widget showing the most recent quest order after a background quest was created.
- Dismissed a stale quest sheet when the app returns from the background, and refreshed the available actions once a deadline passes.
- Dropped the redundant "0 minutes" from English countdowns and shortened the English escalation marker so it fits its row.

### Internal

- Published the en-US App Store listing with locale-stable screenshots and per-locale release notes.
- Authenticated store uploads with an App Store Connect API key and submitted the committed build number unchanged.
- Added a localization gate that fails on a missing translation or a stray Korean literal.

## [1.1.0] - 2026-08-08

### Added

- Choose the hero's appearance from a dedicated settings screen.
- Watch the hero swing a sword in a battle scene when a quest is completed.
- See monsters rendered as stable per-quest pixel-art variants from an expanded sprite catalog.

### Fixed

- Kept an accepted completion applied when its row scrolls away mid-animation.
- Surfaced the mourning state and the battle scene to VoiceOver, and preserved the battle layout under accessibility text sizes.

### Internal

- Generated combat and hero sprites from approved source sheets with provenance, fringe, and output validation.
- Emitted a blank line before the retention baseline data-quality list.

## [1.0.1] - 2026-08-05

### Changed

- Aligned the Home Screen widget with the app's monster and completion artwork for better readability.

### Fixed

- Bounded overlong quest titles so they no longer affect layout or stored data.
- Handled quest details in notifications and the widget more safely and reliably.

### Internal

- Automated App Store asset preparation (release notes and deterministic store screenshots) behind fastlane lanes.
- Declared export compliance and finalized the publisher identity and store legal URLs.

## [1.0.0] - 2026-07-24

### Added

- Create, edit, complete, retry, and delete deadline-based quests in a shame-free daily dungeon.
- Derive urgency, monster strength, victories, and temporary daily graves from local quest facts.
- Receive local due-soon and deadline notifications with deterministic rescheduling and cleanup.
- View the dungeon from Home Screen widgets and complete pending quests with one tap.
- See pixel-art heroes, monsters, rewards, battle feedback, and a three-frame breathing animation.

### Fixed

- Made swipe-to-complete actions reliable and kept app and widget completion facts aligned.

### Internal

- Added local-only retention measurement with privacy-safe retry-event identity and upgrade handling.
- Added deterministic tests for quest derivation, notifications, widgets, onboarding, daily focus, and recovery flows.

[Unreleased]: https://github.com/AndrewDongminYoo/quest-keeper/compare/v1.2.0+26081501...HEAD
[1.2.0]: https://github.com/AndrewDongminYoo/quest-keeper/compare/v1.1.0+26080813...v1.2.0+26081501
[1.1.0]: https://github.com/AndrewDongminYoo/quest-keeper/compare/v1.0.0+26072410...v1.1.0+26080813
[1.0.1]: https://github.com/AndrewDongminYoo/quest-keeper/compare/v1.0.0+26072410...v1.0.1+26080501
[1.0.0]: https://github.com/AndrewDongminYoo/quest-keeper/releases/tag/v1.0.0+26072410
