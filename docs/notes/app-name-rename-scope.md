# App Name Rename Scope

Working note inventorying every place the app name is user-visible or asserted, so a rename can be executed in one pass.
Written 2026-08-15 while shipping 1.2.0.

## Why this exists

Apple refuses to claim `Quest Keeper` for a second App Store locale — adding the en-US localization fails with _"the app name is already being used by another app"_, most likely against [The Quest Keeper](https://apps.apple.com/us/app/the-quest-keeper/id970721313).
A suffix does not clear it; `Quest Keeper: Pixel To-Do` and `Quest Hero` were both rejected, and `TODO Slayer` was accepted.

So 1.2.0 shipped with a split identity: the en-US listing is titled `TODO Slayer` while everything else — the Korean listing, the home screen, and every in-app string — still says `Quest Keeper`.
The en-US description and release notes are part of that split and read `Quest Keeper` under a `TODO Slayer` title.

**Decision, 2026-08-15: correct this in the next version, provided 1.2.0 is not rejected in review.**
The target name is `TODO Slayer` in both locales.

## Inventory

### Rendered brand text

`QuestKeeperShared/Brand.swift` owns both forms, and the rename edits them there:

- `Brand.displayName` (`"QUEST KEEPER"`) — the dungeon header in `HomeDungeonBoardView` and in the widget.
- `Brand.shortName` (`"QUEST"`) — the `systemSmall` widget header, where the full name does not fit. **This needs its own short form chosen for the new name, not a truncation of it**, and it is the one site the sweep below cannot see, because it has no space to match on.

These were three separate `Text(verbatim:)` literals until they were consolidated here.
That mattered because no gate covers them: `scripts/test-localization.sh` flags stray **Korean** literals, and Latin text inside `Text(verbatim:)` passes every check while rendering the name on screen.
They are constants rather than catalog keys because the product name is not localized — a catalog would spread each one across a Swift `defaultValue:` plus `ko` plus `en` for no benefit.
`WidgetStrings.configurationDisplayName` is the one forced exception, since WidgetKit's configuration takes a `LocalizedStringResource`.

### Bundle display names — two independent declarations

The app and the widget extension each carry their own, and neither derives from the other:

- `QuestKeeper.xcodeproj/project.pbxproj:518` and `:565` — `INFOPLIST_KEY_CFBundleDisplayName`, one per configuration.
- `QuestKeeperWidget/Info.plist:8` — the widget extension's `CFBundleDisplayName`, a plain plist string.

Renaming only the build setting leaves the widget extension showing the old name in the system UI.

### Catalog strings

Each of these lives in **three** places: the Korean `defaultValue:` at the Swift call site, the `ko` and `en` values in the catalog, and — for two of them — a literal assertion in `QuestKeeperTests`.
Changing only one leaves the others behind.

| Key                                               | Swift `defaultValue:`                             | Catalog                                   | Test                          |
| ------------------------------------------------- | ------------------------------------------------- | ----------------------------------------- | ----------------------------- |
| `widget.configuration.displayName`                | `QuestKeeperWidget/WidgetStrings.swift:123`       | `QuestKeeperWidget/Localizable.xcstrings` | —                             |
| `appIntent.createQuest.description`               | `QuestKeeper/Intents/CreateQuestIntent.swift:125` | `QuestKeeper/Localizable.xcstrings`       | —                             |
| `appIntent.createQuest.result.permissionRequired` | `QuestKeeper/Intents/CreateQuestIntent.swift:66`  | `QuestKeeper/Localizable.xcstrings`       | `AppStringsTests.swift:95-96` |
| `notification.permissionBanner.body`              | `QuestKeeper/Views/AppStrings.swift:154`          | `QuestKeeper/Localizable.xcstrings`       | `AppStringsTests.swift:46,50` |

That test coverage is a feature, not an obstacle: `AppStringsTests` is what refuses a half-applied edit.
It caught exactly that during the banner fix below.

`notification.permissionBanner.body` used to say `QuestKeeper` with no space in both locales, while Settings lists the app under `CFBundleDisplayName` as `Quest Keeper` — it pointed users at a name that was not on the screen it sent them to.
That was a defect independent of the rename and is already fixed; every user-facing string now uses the spaced form.

### Gates that pin the current name

- `scripts/test-release-display-names.sh:16-25` — asserts the widget plist value equals `Quest Keeper` **and** that the pbxproj contains exactly two `INFOPLIST_KEY_CFBundleDisplayName = "Quest Keeper";` lines.
  This script fails by construction the moment the rename lands, so its expected value changes in the same commit.

### Store screenshots — regenerate, do not edit

`fastlane/screenshots/generated/{ko,en-US}/` holds 16 tracked PNGs, and the dungeon header is rendered into the image — `iPhone 17 Pro Max-01-dungeon.png` shows `QUEST KEEPER` in pixels.
No text search can find it, and changing `Brand.displayName` does not update an existing PNG.
Re-run `bundle exec fastlane screenshots` after the code change, or the new listing ships advertising the old name.

### Store metadata

- `fastlane/metadata/ko/name.txt` — plus the Korean localization in App Store Connect.
- `fastlane/metadata/ko/description.txt` and `fastlane/metadata/en-US/description.txt` — both open with the name.
- The `<Name> X.Y.Z` first line of each new `docs/releases/<version>/<locale>.txt`.

### Docs

- `DESIGN.md:29` — the Screen Model's literal header. `DESIGN.md` declares itself the owner of the current visual direction, so leaving it stale would steer later UI work back to the old brand.
- `docs/store/app-store-listing.md` — title, name field, and description prose.
- `docs/legal/privacy-policy.md` and `docs/legal/terms-of-service.md` — re-copied into the landing repo's `content/legal/*.ko.md`, so the rename lands in `quest-keeper-landing` too.
- `LINEAR.md` — names the Linear project, which is a workspace label rather than product copy; change it only if the Linear project is renamed too.

### Deliberately unchanged

- Bundle identifiers `kr.donminzzi.QuestKeeper` and `kr.donminzzi.QuestKeeper.Widget`, and the App Group — an App Store bundle ID cannot be changed after release.
- The repository, Xcode project, scheme, target names, and `PRODUCT_NAME`.
- `Logger(subsystem:)` values, which follow the bundle identifier.
- `docs/specs/`, `docs/plans/`, and everything under `docs/releases/` — these record decisions and shipped copy as they stood at the time, so they keep the old name.
  The whole `docs/releases/` tree is historical by construction: a version's notes are written once at cut time and never revised, so any directory that exists is already shipped. Naming individual versions here would go stale at every release.

## Traps

- **A name that saves for one locale is not proven for another.** Claims are per locale; that is the whole reason this note exists. Save `TODO Slayer` on the Korean localization in App Store Connect and confirm the page save before editing `name.txt`.
- **Renaming the Korean listing releases the `Quest Keeper` claim.** Given how the en-US attempts went, re-claiming it later should be assumed impossible.
- **App Store Connect's App Information page saves every localization atomically and misattributes which one failed** — a rejected name surfaces as errors on the other locale's fields.
- **A store name change goes through review**, so it cannot be a metadata-only touch-up after submission.

## Verification

1. `bash scripts/test-localization.sh` → catalogs complete in `ko` and `en`.
2. `bash scripts/test-release-display-names.sh` → passes only once its own expected name is updated alongside the plist and the build settings.
3. `xcodebuild test -only-testing:QuestKeeperTests -parallel-testing-enabled NO` → `AppStringsTests` is the gate that catches a half-applied string edit.
4. Sweep the repository for the old name.
   The displayed brand always contains a space, while identifiers, paths, bundle IDs, and module names never do, so matching on the space is what separates copy from code:

   ```bash
   rg -n --glob '!.git' -e 'Quest Keeper' -e 'QUEST KEEPER' . \
     | grep -vE '^\./(docs/(specs|plans|releases)/|docs/notes/app-name-rename-scope\.md)'
   ```

   As of this note it returns **41 hits**, and every one of them is in the inventory above.
   After the rename the sweep must return nothing.

   The exclusions are the paths that keep the old name on purpose: `docs/specs/`, `docs/plans/` and `docs/releases/` are historical records, and this file describes the name rather than displaying it.
   The **next** version's release notes are not covered by this sweep — they do not exist yet when the rename lands. Their `<Name> X.Y.Z` first line is the Store metadata bullet's job, at cut time.

   Then check the one site it structurally cannot see:

   ```bash
   rg -n 'static let shortName' QuestKeeperShared/Brand.swift
   ```

5. Re-run `bundle exec fastlane screenshots` and look at the regenerated PNGs — the header is pixels, so no gate can read it.
6. Launch in both locales and read the dungeon header, the home screen icon label, the widget gallery entry, and the notification permission banner.
   The gate cannot judge any of these — see the reasoning in `docs/specs/018-english-localization.md`.
