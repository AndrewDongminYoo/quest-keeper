# Changelog

All notable changes to TODO Slayer will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.4.0] - 2026-09-04

### Added

- Added optional Tip Jar purchases that support development without changing progress or locking features.
- Added daily routines, a rotating routine roster, and a Hall of Fame for completed quests.
- Added user-controlled reengagement reminders, including local attribution for opened reminders.
- Added a weekly review that summarizes the week that just ended and starts the next planning flow.
- Recorded completions made after a deadline instead of treating them as unavailable actions.

### Fixed

- Preserved reminder capacity for the requests that are actually scheduled, and reconciled reminders after a quest is created from Shortcuts.
- Restored the previous valid reminder schedule when a replacement request fails partway through.
- Reopened the shared store before the Shortcuts creation path reads or writes it.
- Kept delayed Tip Jar purchase outcomes available when the app receives them after launch.
- Showed a visible error when the store refuses a write and kept unsaved state out of notifications and widgets.
- Corrected reengagement measurement so an opened reminder is attributed once to its matching send.
- Closed read-only sheets before opening a quest from a notification, and deferred that route until an active editor is dismissed.

### Internal

- Added the full UI test suite to CI and resolved simulator destinations from the runner's installed devices.
- Added localization, release-version, store-screenshot, retry-summary, and test-result artifact checks to CI.
- Restricted store screenshots to the six screens available under the Release feature policy.
- Added cross-process measurement for the app and widget store and documented the observed visibility boundary.

## [1.3.0] - 2026-08-17

### Changed

- Renamed the app from Quest Keeper to TODO Slayer, across the home screen, the widget, every in-app string, and both store listings. Existing quests and records are untouched.

### Fixed

- Gave the small widget its width back, so the quest badge and the remaining time are legible instead of clipped, and stopped the medium widget inheriting the small one's inset.
- Rolled a widget completion back instead of passing silently when its write fails, and committed quest facts before publishing the widget snapshot so the widget never shows a state the app has not saved.
- Ordered and capped the scheduled reminders so the quests nearest their deadline are the ones that fire, and restored reminders the cap had evicted for an add that then failed.
- Stopped VoiceOver reading a quest's guidance twice.
- Kept the app running with an explanation instead of stopping when its store cannot be opened.
- Stopped the English widget empty state truncating, shortened the English victory label to fit, and named the app in the notification permission banner the way Settings lists it.

### Internal

- Blocked `fastlane release` when a store locale's name, description, and screenshots do not all name the same app, and made the lane regenerate the screenshots from the current build rather than trusting committed PNGs.
- Gave the rendered product name one home in `Brand`, so a future rename edits two constants rather than three view literals.
- Replaced store screenshots on upload instead of appending to whatever the listing already held.
- Updated fastlane to 2.238.0.

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

[Unreleased]: https://github.com/AndrewDongminYoo/quest-keeper/compare/v1.4.0+26090413...HEAD
[1.4.0]: https://github.com/AndrewDongminYoo/quest-keeper/compare/v1.3.0+26081713...v1.4.0+26090413
[1.3.0]: https://github.com/AndrewDongminYoo/quest-keeper/compare/v1.2.0+26081501...v1.3.0+26081713
[1.2.0]: https://github.com/AndrewDongminYoo/quest-keeper/compare/v1.1.0+26080813...v1.2.0+26081501
[1.1.0]: https://github.com/AndrewDongminYoo/quest-keeper/compare/v1.0.0+26072410...v1.1.0+26080813
[1.0.1]: https://github.com/AndrewDongminYoo/quest-keeper/compare/v1.0.0+26072410...v1.0.1+26080501
[1.0.0]: https://github.com/AndrewDongminYoo/quest-keeper/releases/tag/v1.0.0+26072410
