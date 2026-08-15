# App Name Rename Scope

Working note inventorying every place the app name is user-visible, so a rename can be executed in one pass.
Written 2026-08-15 while shipping 1.2.0.

## Why this exists

Apple refuses to claim `Quest Keeper` for a second App Store locale — adding the en-US localization fails with _"the app name is already being used by another app"_, most likely against [The Quest Keeper](https://apps.apple.com/us/app/the-quest-keeper/id970721313).
A suffix does not clear it; `Quest Keeper: Pixel To-Do` and `Quest Hero` were both rejected, and `TODO Slayer` was accepted.

So 1.2.0 shipped with a split identity: the en-US listing is titled `TODO Slayer` while everything else — the Korean listing, the home screen, and every in-app string — still says `Quest Keeper`.
The en-US description and release notes are part of that split and read `Quest Keeper` under a `TODO Slayer` title.

**Decision, 2026-08-15: correct this in the next version, provided 1.2.0 is not rejected in review.**
The target name is `TODO Slayer` in both locales.

## Inventory

### App code — literals outside the String Catalogs

No gate covers these.
`scripts/test-localization.sh` flags stray **Korean** literals, and all three of these are Latin text inside `Text(verbatim:)`, so they pass every check while displaying the name.

- `QuestKeeper/Views/HomeDungeonBoardView.swift:278` — the app's dungeon header, `"QUEST KEEPER"`.
- `QuestKeeperWidget/WidgetDungeonView.swift:73` — the widget's header, a separate copy of the same literal.
- `QuestKeeperWidget/WidgetDungeonView.swift:122` — `"QUEST"`, the `systemSmall` header, a shortened form of the same brand for the narrower layout. A new name needs its own short form here, not a mechanical substitution.

Moving all three into catalog keys is worth doing on its own, independently of the rename — it closes the blind spot and makes the eventual rename a one-place edit per target.

- `QuestKeeper.xcodeproj/project.pbxproj:518` and `:565` — `INFOPLIST_KEY_CFBundleDisplayName`, the home screen label, one per configuration.

### App code — catalog strings

Every one of these lives in **two** places: the Korean `defaultValue:` at the Swift call site, and the `ko` plus `en` values in the catalog.
Changing only the catalog leaves the source literal behind, and vice versa.

| Key                                               | Swift `defaultValue:`                             | Catalog                                   |
| ------------------------------------------------- | ------------------------------------------------- | ----------------------------------------- |
| `widget.configuration.displayName`                | `QuestKeeperWidget/WidgetStrings.swift:123`       | `QuestKeeperWidget/Localizable.xcstrings` |
| `appIntent.createQuest.description`               | `QuestKeeper/Intents/CreateQuestIntent.swift:125` | `QuestKeeper/Localizable.xcstrings`       |
| `appIntent.createQuest.result.permissionRequired` | `QuestKeeper/Intents/CreateQuestIntent.swift:66`  | `QuestKeeper/Localizable.xcstrings`       |
| `notification.permissionBanner.body`              | `QuestKeeper/Views/AppStrings.swift:154`          | `QuestKeeper/Localizable.xcstrings`       |

`notification.permissionBanner.body` carries a separate pre-existing defect worth fixing whether or not the rename happens.
It says `QuestKeeper` with no space, in both locales, while Settings lists the app under `CFBundleDisplayName` as `Quest Keeper` — it tells users to look for a name that is not there.

### Store metadata

- `fastlane/metadata/ko/name.txt` — plus the Korean localization in App Store Connect.
- `fastlane/metadata/ko/description.txt` and `fastlane/metadata/en-US/description.txt` — both open with the name.
- The `<Name> X.Y.Z` first line of each new `docs/releases/<version>/<locale>.txt`.

### Docs

- `docs/store/app-store-listing.md` — title and description prose.
- `docs/legal/privacy-policy.md` and `docs/legal/terms-of-service.md` — these are re-copied into the landing repo's `content/legal/*.ko.md`, so the rename lands in `quest-keeper-landing` too.

### Deliberately unchanged

- Bundle identifiers `kr.donminzzi.QuestKeeper` and `kr.donminzzi.QuestKeeper.Widget`, and the App Group — an App Store bundle ID cannot be changed after release.
- The repository, Xcode project, scheme, target names, and `PRODUCT_NAME`.
- `Logger(subsystem:)` values, which follow the bundle identifier.
- Shipped release notes under `docs/releases/1.0.x/` and `1.1.0/` — they record what the store showed at the time.

## Traps

- **A name that saves for one locale is not proven for another.** Claims are per locale; that is the whole reason this note exists. Save `TODO Slayer` on the Korean localization in App Store Connect and confirm the page save before editing `name.txt`.
- **Renaming the Korean listing releases the `Quest Keeper` claim.** Given how the en-US attempts went, re-claiming it later should be assumed impossible.
- **App Store Connect's App Information page saves every localization atomically and misattributes which one failed** — a rejected name surfaces as errors on the other locale's fields.
- **A store name change goes through review**, so it cannot be a metadata-only touch-up after submission.

## Verification

1. `bash scripts/test-localization.sh` → catalogs complete in `ko` and `en`.
2. Sweep the three shapes a user-facing name can take.
   Matching on the shapes rather than on the word avoids the type names, bundle identifiers, and file-header comments that keep the old spelling by design:

   ```bash
   rg -n --glob '*.swift' --glob '*.xcstrings' \
     -e 'verbatim: "[^"]*QUEST' \
     -e 'defaultValue: "[^"]*[Qq]uest ?[Kk]eeper' \
     -e '"value" : "[^"]*[Qq]uest ?[Kk]eeper' \
     QuestKeeper/ QuestKeeperShared/ QuestKeeperWidget/
   ```

   Run against 1.2.0 this returns **15 hits**, which is the full work list: 3 `verbatim` literals, 4 `defaultValue:` literals, and 8 catalog values (4 keys × `ko` + `en`).
   After the rename it must return nothing.

3. Launch in both locales and read the dungeon header, the home screen icon label, the widget gallery entry, and the notification permission banner.
   The gate cannot judge any of these — see the reasoning in `docs/specs/018-english-localization.md`.
