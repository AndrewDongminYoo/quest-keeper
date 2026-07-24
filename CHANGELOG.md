# Changelog

All notable changes to QuestKeeper will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/AndrewDongminYoo/quest-keeper/compare/v1.0.0+26072412...HEAD
[1.0.0]: https://github.com/AndrewDongminYoo/quest-keeper/releases/tag/v1.0.0+26072412
