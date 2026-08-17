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
- `Brand.shortName` (`"QUEST"`) — the `systemSmall` widget header, where the full name does not fit. **This needs its own short form chosen for the new name, not a truncation of it**, and it is the one site **neither** sweep in Verification can see — `"QUEST"` matches no spelling of the full name.

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
  `fastlane/metadata/<locale>/release_notes.txt` is generated from those sources by `scripts/prepare-release-notes.sh` and needs no separate edit — until the next release is cut it still holds the shipped version's text, which is why it sits under "Deliberately unchanged".

### Docs

- `DESIGN.md` — the Screen Model's literal header at `:29`, plus the title and the prose at `:11`. `DESIGN.md` declares itself the owner of the current visual direction, so leaving it stale would steer later UI work back to the old brand.
- **`README.md`, `CHANGELOG.md`, `BLUEPRINT.md` — product prose written in the unspaced form.** `README.md:1,3` is the title and the one-line description; `:128` tells a tester to "Add the QuestKeeper widget"; `:130` names the foregrounded app. `CHANGELOG.md:3` and `BLUEPRINT.md:1` name the project the same way.
  These are the reason the spaced sweep is not enough on its own — see the second command in Verification. Their other hits are directory paths and `-scheme` arguments, which do not change.
- `docs/store/app-store-listing.md` — title, name field, and description prose.
- `docs/legal/privacy-policy.md` and `docs/legal/terms-of-service.md` — re-copied into the landing repo's `content/legal/*.ko.md`, so the rename lands in `quest-keeper-landing` too.
  Two more files there carry the name and this side cannot reach them: `content/legal/privacy.en.md` and `content/legal/terms.en.md` have no upstream in this repository, so the re-copy does not touch them and they have to be edited by hand. Eight lines across the four files, two per file.
  **The landing repository's trigger is the Korean name claim in App Store Connect, and only that** — not this repository's merge. Its legal documents are published at the URL registered in App Store Connect, so copying them across before the claim lands would publish a Korean privacy policy naming an app that the Korean store does not have. That is the reverse of the hazard the Traps section describes: here the copy is harmless in this repository and harmful in the one that serves it.
- `LINEAR.md` — names the Linear project in prose and in a field. **Follows the Korean listing, and only it.**
  Operator decision, 2026-08-15: renaming the Linear project is premature until the Korean app name actually becomes `TODO Slayer`. If this plan is executed, rename the project and update both lines in the same pass; if the Korean listing keeps `Quest Keeper` for any reason, `LINEAR.md` keeps it too and both hits classify as unchanged.
  Linear keeps the project's URL slug across a rename, so the link in that file stays valid either way.

### Deliberately unchanged

- Bundle identifiers `kr.donminzzi.QuestKeeper` and `kr.donminzzi.QuestKeeper.Widget`, and the App Group — an App Store bundle ID cannot be changed after release.
- The repository, Xcode project, scheme, target names, and `PRODUCT_NAME`.
- `Logger(subsystem:)` values, which follow the bundle identifier.
- `docs/specs/`, `docs/plans/`, `docs/notes/`, and everything under `docs/releases/` — these record decisions, verification runs, and shipped copy as they stood at the time, so they keep the old name.
  The whole `docs/releases/` tree is historical by construction: a version's notes are written once at cut time and never revised, so any directory that exists is already shipped. Naming individual versions here would go stale at every release.
- `fastlane/metadata/<locale>/release_notes.txt` — generated by `scripts/prepare-release-notes.sh` from `docs/releases/<version>/`, and holding the shipped version's text until the next release is cut.
- `CLAUDE.md` — its `QuestKeeper` hits name the repository, the scheme, the targets, and the source directories, all of which stay. The one prose hit at `:7` names the project rather than the store product, and the project keeps its name; it classifies here for the same reason as the entry below.
- **This file.** It describes the name rather than displaying it, and quotes the old one throughout so the record still reads after the rename.

## Traps

- **A name that saves for one locale is not proven for another.** Claims are per locale; that is the whole reason this note exists. Save `TODO Slayer` on the Korean localization in App Store Connect and confirm the page save before editing `name.txt`.
- **Renaming the Korean listing releases the `Quest Keeper` claim.** Given how the en-US attempts went, re-claiming it later should be assumed impossible.
- **App Store Connect's App Information page saves every localization atomically and misattributes which one failed** — a rejected name surfaces as errors on the other locale's fields.
- **A store name change goes through review**, so it cannot be a metadata-only touch-up after submission.

## Verification

1. `bash scripts/test-localization.sh` → catalogs complete in `ko` and `en`.
2. `bash scripts/test-release-display-names.sh` → passes only once its own expected name is updated alongside the plist and the build settings.
3. `xcodebuild test -scheme QuestKeeper -destination <sim> -only-testing:QuestKeeperTests -parallel-testing-enabled NO` → `AppStringsTests` is the gate that catches a half-applied string edit.
   Take the destination from the canonical invocation in `CLAUDE.md`, which pins the simulator by UDID; the UDIDs are recreated periodically, so copying one into this note would rot.
4. Sweep the repository for the old name.
   The displayed brand always contains a space, while identifiers, paths, bundle IDs, and module names never do, so matching on the space is what separates copy from code:

   ```bash
   rg -n --glob '!.git' -e 'Quest Keeper' -e 'QUEST KEEPER' .
   ```

   **The pass condition is that every remaining hit falls under "Deliberately unchanged" — not that the output is empty.**
   Against 1.2.0 it returns 70 hits: the 38 sites in the inventory above, plus 32 that legitimately keep the old name — `docs/specs/`, `docs/plans/`, `docs/releases/`, the generated `fastlane/metadata/<locale>/release_notes.txt` copies, and this file's own 10.

   An earlier draft of this note demanded an empty result and carried a `grep -v` denylist to get there.
   Three review rounds in a row found another file the denylist had not anticipated — the shipped 1.2.0 release notes, then the generated `fastlane/metadata/<locale>/release_notes.txt` copies, then `LINEAR.md`.
   Each fix widened the denylist and exposed the next gap in it, because the product name appears across the whole repository and a hand-maintained exclusion list cannot stay exhaustive.
   Classifying the hits is the check; an empty result was never achievable.

   The **next** version's release notes are not covered here — they do not exist yet when the rename lands. Their `<Name> X.Y.Z` first line is the Store metadata bullet's job, at cut time.

5. Sweep for the **unspaced** form, which the search above cannot see:

   ```bash
   rg -n '\bQuestKeeper\b' --glob '*.md' . \
     | grep -vE '^\./docs/(specs|plans|notes)/'
   ```

   Same pass condition: classify, do not expect empty.
   Against 1.2.0 this returns 28 hits across `README.md`, `CHANGELOG.md`, `BLUEPRINT.md`, `DESIGN.md`, `CLAUDE.md`, `LINEAR.md` and this file — most of them directory paths and `-scheme` arguments that do not change, and a handful of product prose that does.
   Restricting to `*.md` is what makes this usable: in Swift the same token is the module name on almost every line, while in prose it is the product.

   The premise that a space separates copy from code was wrong, and the README instructions are why. An earlier draft leaned on it alone and would have left a tester being told to add a widget under a name that no longer exists.

   Then check the one site it structurally cannot see:

   ```bash
   rg -n 'static let shortName' QuestKeeperShared/Brand.swift
   ```

6. Re-run `bundle exec fastlane screenshots` and look at the regenerated PNGs — the header is pixels, so no gate can read it.
7. Launch in both locales and read the dungeon header, the home screen icon label, the widget gallery entry, and the notification permission banner.
   The gate cannot judge any of these — see the reasoning in `docs/specs/018-english-localization.md`.
