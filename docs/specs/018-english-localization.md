# English Localization

Tracked as Linear AND-110. Covers the app UI and local notifications only; the `en-US` App Store listing and English screenshots are a follow-up slice of the same issue.

## Goal

Ship an English UI so the app works outside Korean-reading users, and make the string layer explicit enough that a third locale is additive rather than another sweep.

Korean stops being hardcoded and becomes one value among others. `DESIGN.md` currently states "Korean UI is the default"; that line changes to name Korean as the source-of-record voice with English as a peer locale.

## Voice

English keeps the Korean register rather than reaching for a different one: quest-flavored, plain, shame-free.
`battle`, `victory`, and `dungeon` carry over literally; sentences stay unadorned.

| Korean                                          | English                                                  |
| ----------------------------------------------- | -------------------------------------------------------- |
| 첫 승리를 시작해볼까요?                         | Ready for your first victory?                            |
| 2분 안에 끝낼 수 있는 작은 전투부터 시작하세요. | Start with a small battle you can finish in two minutes. |
| 2분 전투 시작                                   | Start a 2-Minute Battle                                  |
| 오늘의 던전이 비었습니다                        | Today's dungeon is empty                                 |
| 내일 도전하기                                   | Try Again Tomorrow                                       |
| 오늘의 무덤                                     | Today's grave                                            |

The prohibitions in `DESIGN.md` hold in English: nothing that reads as blame. No "You failed", no "You missed it again", no running tally of shortfalls.

## Key naming

Keys are semantic, not source strings: a dot-separated, lowercase hierarchy whose segment count is not fixed — most keys are three segments (`<area>.<element>.<role>`), but some, like `hero.appearance.gender.male`, run to four.

```plaintext
dungeon.empty.title
dungeon.empty.body
quest.action.complete
quest.action.retryTomorrow
focus.section.title
notification.dueSoon.body
a11y.monster.label
monster.slime
hero.appearance.gender.male
```

Semantic keys were chosen over source strings so Korean copy edits do not invalidate the translation linkage.

Call sites never reference a raw key string.
Each key is wrapped once in a `LocalizedStringResource` constant declared in `AppStrings` (`QuestKeeper/Views/`), `WidgetStrings` (`QuestKeeperWidget/`), or `SharedStrings` (`QuestKeeperShared/`), with the Korean copy supplied as that resource's `defaultValue`.
This supersedes the original assumption above: a missing catalog entry does not render the raw key, it falls back to the `defaultValue` baked into the resource, i.e. Korean.
The verification gate below still exists, now to catch an empty/missing catalog value and any stray Korean literal that bypasses `AppStrings` / `WidgetStrings` / `SharedStrings` entirely.

## Catalog placement

Two `Localizable.xcstrings` files, one per bundle: the app target and the widget extension. They are separate bundles, so a single catalog cannot serve both.

Strings that `QuestKeeperShared/` exposes to both — `MonsterArtworkSelection` monster names, and any other shared display text — are declared with the same key in both catalogs. Duplication across two catalogs is accepted over introducing a resource bundle for nine strings.

## Conversion classes

| Class                                | Sites                                                 | Treatment                                                                                    |
| ------------------------------------ | ----------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| `Text` / `Button` / `Label` literals | ~60                                                   | Replace the literal with the key. These take `LocalizedStringKey`, so no other code changes. |
| Accessibility modifiers              | 21                                                    | `String(localized:)` — these take `String`, which is not localized automatically.            |
| `String`-returning properties        | those among 24 declarations that produce display text | `String(localized:)`. Includes `HeroAppearance.title`, `MonsterKind.localizedName`.          |
| Notification copy                    | 4                                                     | `String(localized:)` inside `QuestNotificationPlanner`.                                      |

Counts are from `rg` over `QuestKeeper/`, `QuestKeeperShared/`, and `QuestKeeperWidget/` on 2026-08-08, excluding comment lines: 150 Korean string literals across 21 files.

## Plurals

Twelve sites interpolate a count or duration. Korean has no plural agreement, so the current code concatenates freely; English does.

The remaining-time strings in `DungeonPresentation.swift` are the sharp case:

```swift
if minutes >= 1440 { return "\(minutes / 1440)일 남음" }
if minutes >= 60 { return "\(minutes / 60)시간 \(minutes % 60)분 남음" }
return "\(minutes)분 남음"
```

These stay in their current display format and gain `one`/`other` variations in the English catalog entries.
Replacing them with `RelativeDateTimeFormatter` was considered and rejected for this slice: it would change what the UI says ("3시간 20분 남음" becomes "3시간 후"), which is a product change rather than a localization one.

The compound "3시간 20분 남음" case needs its hour and minute components as separate keys, because English pluralizes each independently.

## Verification

- `scripts/test-localization.sh` parses each `.xcstrings` and fails when any key is missing a `ko` or `en` value, or carries an empty one. This is the gate against the semantic-key failure mode.
- A reverse guard fails when a Korean string literal survives in a user-facing position, in the same shape as the derived-state guard in `CLAUDE.md`.
- `xcodebuild test -only-testing:QuestKeeperTests` stays green.
- Manual pass with the simulator language set to English, walking every screen and the widget.

## Out of scope

- `fastlane/metadata/en-US/` and English store screenshots — the follow-up slice, which also needs `scripts/prepare-release-notes.sh` generalized past its hardcoded `ko` destination.
- Locales beyond Korean and English.
- RTL layout.
- Date and number format redesign; existing `Calendar` and `DateFormatter` usage stands.
