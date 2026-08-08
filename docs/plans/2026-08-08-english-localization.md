# English Localization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship an English UI and English local notifications alongside Korean, with every user-facing string resolved through a String Catalog under semantic keys.

**Architecture:** Two `Localizable.xcstrings` catalogs, one per bundle (app, widget). Every key is declared once as a `LocalizedStringResource` constant in a per-area `Strings` namespace, so call sites reference a symbol rather than a string and a typo is a compile error. Pure functions that produce display text take an injected `Locale`, matching the existing `now`/`calendar` injection in `HeroDerivation`, which keeps their tests deterministic in both locales.

**Tech Stack:** Swift 6 strict concurrency, SwiftUI, String Catalog (`.xcstrings`), `LocalizedStringResource`, `String(localized:defaultValue:locale:)`, Swift Testing.

## Global Constraints

- Spec of record: `docs/specs/018-english-localization.md`. Linear issue: AND-110.
- Voice: quest-flavored, plain, shame-free. `battle`, `victory`, `dungeon` carry over literally. Nothing that reads as blame — no "You failed", no "You missed it again", no running tally of shortfalls.
- Key format: dot-separated, most general segment first — `<area>.<element>.<role>`, dropping trailing segments that carry no meaning. Each segment is lowerCamelCase, so multi-word segments read `countdown.dueNow` and `dungeon.firstWin.title`. Segment count is not fixed: `monster.slime` and `hero.appearance.gender.male` are both correct.
- Korean is the development language and stays visible in code as each resource's `defaultValue`.
- Unit tests use Swift Testing (`import Testing`, `@Test`, `#expect`), never XCTest.
- `SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`. No new warnings.
- Derivation and action namespaces stay caseless `nonisolated enum`s; state values stay `nonisolated struct`s.
- This project sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so a bare `extension` does **not** inherit the primary type's `nonisolated`. Every extension of `AppStrings`, `SharedStrings`, or `WidgetStrings` must be written `nonisolated extension …`, or its members become `@MainActor` and cannot be referenced from the nonisolated pure functions that call them. Existing precedent: `QuestOutcome.swift:19`, `WidgetDungeonPayload.swift:25`.
- Scope is the app UI and notifications. `fastlane/metadata/en-US/` and English screenshots are out of scope.
- Every task ends with `trunk fmt` and `trunk check` clean on the files it touched.

**Test command** — confirm the simulator UDID first with `xcrun simctl list devices available`, and prefer an already-booted simulator:

```bash
xcodebuild test -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=CDF2239B-B46C-4A44-A09E-ED656EF7F9EA' \
  -only-testing:QuestKeeperTests
```

---

### Task 1: Catalog scaffolding and the missing-translation gate

The gate comes first because every later task depends on it to catch an unfilled key. Build it against a deliberately broken fixture so its pass is not vacuous.

**Files:**

- Create: `QuestKeeper/Localizable.xcstrings`
- Create: `QuestKeeperWidget/Localizable.xcstrings`
- Create: `scripts/test-localization.sh`
- Modify: `QuestKeeper.xcodeproj/project.pbxproj` (add both catalogs to their targets' resources build phase; add `ko` to `knownRegions` and set `developmentRegion = ko`)

**Interfaces:**

- Consumes: nothing.
- Produces: `scripts/test-localization.sh <catalog...>` — exits 0 when every key in every given catalog has non-empty `ko` and `en` values, exits 1 with `FAIL: <key> missing <locale>` otherwise. Later tasks run it after adding keys.

- [ ] **Step 1: Create both catalogs with one real key**

Write this to `QuestKeeper/Localizable.xcstrings` and, with the same shape, to `QuestKeeperWidget/Localizable.xcstrings`:

```json
{
  "sourceLanguage": "ko",
  "strings": {
    "dungeon.empty.title": {
      "localizations": {
        "en": {
          "stringUnit": {
            "state": "translated",
            "value": "Today's dungeon is empty"
          }
        },
        "ko": {
          "stringUnit": {
            "state": "translated",
            "value": "오늘의 던전이 비었습니다"
          }
        }
      }
    }
  },
  "version": "1.0"
}
```

- [ ] **Step 2: Write the gate script**

Create `scripts/test-localization.sh`:

```bash
#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ $# -gt 0 ]]; then
	catalogs=("$@")
else
	catalogs=(
		"${repo_root}/QuestKeeper/Localizable.xcstrings"
		"${repo_root}/QuestKeeperWidget/Localizable.xcstrings"
	)
fi

status=0

for catalog in "${catalogs[@]}"; do
	if [[ ! -s ${catalog} ]]; then
		echo "FAIL: missing or empty catalog: ${catalog}" >&2
		status=1
		continue
	fi

	while IFS= read -r problem; do
		echo "FAIL: ${catalog}: ${problem}" >&2
		status=1
	done < <(
		/usr/bin/python3 - "${catalog}" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    catalog = json.load(handle)

for key, entry in sorted(catalog.get("strings", {}).items()):
    localizations = entry.get("localizations", {})
    for locale in ("ko", "en"):
        localization = localizations.get(locale)
        if localization is None:
            print(f"{key} missing {locale}")
            continue
        unit = localization.get("stringUnit")
        variations = localization.get("variations")
        if unit is not None:
            if not unit.get("value", "").strip():
                print(f"{key} has an empty {locale} value")
        elif variations is not None:
            plural = variations.get("plural", {})
            if not plural:
                print(f"{key} has no {locale} plural variations")
            for category, variation in sorted(plural.items()):
                value = variation.get("stringUnit", {}).get("value", "")
                if not value.strip():
                    print(f"{key} has an empty {locale} plural.{category} value")
        else:
            print(f"{key} has no {locale} string unit")
PY
	)
done

if [[ ${status} -eq 0 ]]; then
	echo "localization catalog tests passed"
fi

exit "${status}"
```

Then `chmod +x scripts/test-localization.sh`.

- [ ] **Step 3: Run the gate to verify it passes on good input**

Run: `bash scripts/test-localization.sh`
Expected: `localization catalog tests passed`, exit 0.

- [ ] **Step 4: Make the gate fail before trusting its pass**

Create a broken fixture and confirm each failure shape is caught:

```bash
probe="$(mktemp -d)"
python3 - "$probe/missing.xcstrings" <<'PY'
import json, sys
json.dump({
  "sourceLanguage": "ko",
  "strings": {
    "a.missing.en": {"localizations": {"ko": {"stringUnit": {"state": "translated", "value": "값"}}}},
    "b.empty.en": {"localizations": {
      "ko": {"stringUnit": {"state": "translated", "value": "값"}},
      "en": {"stringUnit": {"state": "new", "value": "   "}}}},
  },
  "version": "1.0",
}, open(sys.argv[1], "w"), ensure_ascii=False)
PY
bash scripts/test-localization.sh "$probe/missing.xcstrings"; echo "exit=$?"
```

Expected: two `FAIL:` lines — `a.missing.en missing en` and `b.empty.en has an empty en value` — and `exit=1`.

- [ ] **Step 5: Wire the catalogs into the Xcode project**

Add `QuestKeeper/Localizable.xcstrings` to the `QuestKeeper` target's resources build phase and `QuestKeeperWidget/Localizable.xcstrings` to the `QuestKeeperWidget` target's. In the `PBXProject` node, set `developmentRegion = ko;` and make `knownRegions` list `en`, `ko`, and `Base`.

- [ ] **Step 6: Verify the build picks up both catalogs**

Run:

```bash
xcodebuild build -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=CDF2239B-B46C-4A44-A09E-ED656EF7F9EA' 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 7: Commit**

```bash
trunk fmt scripts/test-localization.sh
trunk check scripts/test-localization.sh
git add QuestKeeper/Localizable.xcstrings QuestKeeperWidget/Localizable.xcstrings \
  scripts/test-localization.sh QuestKeeper.xcodeproj/project.pbxproj
git commit -m "feat(i18n): add string catalogs and a missing-translation gate"
```

---

### Task 2: Monster names

The smallest real unit, and it already has a test file. Establishes the `Strings` namespace pattern every later task copies.

**Files:**

- Create: `QuestKeeperShared/SharedStrings.swift`
- Modify: `QuestKeeperShared/MonsterArtworkSelection.swift:22-33`
- Modify: `QuestKeeper/Localizable.xcstrings`, `QuestKeeperWidget/Localizable.xcstrings`
- Test: `QuestKeeperTests/MonsterArtworkSelectionTests.swift`

**Interfaces:**

- Consumes: `scripts/test-localization.sh` from Task 1.
- Produces:
  - `enum SharedStrings` with `static func monsterName(_ kind: MonsterKind) -> LocalizedStringResource`.
  - `MonsterKind.localizedName(locale: Locale = .current) -> String` — replaces the current `var localizedName: String`. Every call site must pass through this; Task 9 and Task 10 depend on the signature.

- [ ] **Step 1: Write the failing test**

Replace the name assertions in `QuestKeeperTests/MonsterArtworkSelectionTests.swift` by adding this test:

```swift
@Test("monster names resolve per locale")
func monsterNamesLocalize() {
    #expect(MonsterKind.slime.localizedName(locale: Locale(identifier: "ko")) == "슬라임")
    #expect(MonsterKind.slime.localizedName(locale: Locale(identifier: "en")) == "Slime")
    #expect(MonsterKind.lich.localizedName(locale: Locale(identifier: "ko")) == "리치")
    #expect(MonsterKind.lich.localizedName(locale: Locale(identifier: "en")) == "Lich")
}
```

- [ ] **Step 2: Run it to verify it fails**

Run:

```bash
xcodebuild test -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=CDF2239B-B46C-4A44-A09E-ED656EF7F9EA' \
  -only-testing:QuestKeeperTests/MonsterArtworkSelectionTests
```

Expected: compile failure — `localizedName` takes no arguments.

- [ ] **Step 3: Add the catalog entries**

Add nine keys to **both** catalogs, following the Task 1 entry shape. Korean values are the current literals; English values:

| Key                | ko       | en       |
| ------------------ | -------- | -------- |
| `monster.slime`    | 슬라임   | Slime    |
| `monster.bat`      | 박쥐     | Bat      |
| `monster.mushroom` | 버섯     | Mushroom |
| `monster.skeleton` | 스켈레톤 | Skeleton |
| `monster.orc`      | 오크     | Orc      |
| `monster.mimic`    | 미믹     | Mimic    |
| `monster.dragon`   | 드래곤   | Dragon   |
| `monster.golem`    | 골렘     | Golem    |
| `monster.lich`     | 리치     | Lich     |

- [ ] **Step 4: Create the shared namespace**

Create `QuestKeeperShared/SharedStrings.swift`:

```swift
import Foundation

/// 앱과 위젯이 함께 쓰는 문자열 리소스. 두 번들의 카탈로그에 같은 키가 선언되어 있다.
nonisolated enum SharedStrings {
    static func monsterName(_ kind: MonsterKind) -> LocalizedStringResource {
        switch kind {
        case .slime: LocalizedStringResource("monster.slime", defaultValue: "슬라임")
        case .bat: LocalizedStringResource("monster.bat", defaultValue: "박쥐")
        case .mushroom: LocalizedStringResource("monster.mushroom", defaultValue: "버섯")
        case .skeleton: LocalizedStringResource("monster.skeleton", defaultValue: "스켈레톤")
        case .orc: LocalizedStringResource("monster.orc", defaultValue: "오크")
        case .mimic: LocalizedStringResource("monster.mimic", defaultValue: "미믹")
        case .dragon: LocalizedStringResource("monster.dragon", defaultValue: "드래곤")
        case .golem: LocalizedStringResource("monster.golem", defaultValue: "골렘")
        case .lich: LocalizedStringResource("monster.lich", defaultValue: "리치")
        }
    }
}
```

- [ ] **Step 5: Convert the property to a locale-taking method**

In `QuestKeeperShared/MonsterArtworkSelection.swift`, replace the `var localizedName: String { … }` block with:

```swift
    func localizedName(locale: Locale = .current) -> String {
        var resource = SharedStrings.monsterName(self)
        resource.locale = locale
        return String(localized: resource)
    }
```

- [ ] **Step 6: Fix the three existing call sites**

`localizedName` is now a method. Update:

- `QuestKeeper/Views/QuestRow.swift:254`
- `QuestKeeper/Views/QuestBattleScene.swift:48`
- `QuestKeeperWidget/WidgetDungeonView.swift:211`

Each becomes `…localizedName()`. Their surrounding accessibility labels are converted in Tasks 8 and 9; leave the Korean interpolation in place for now.

- [ ] **Step 7: Run the tests to verify they pass**

Run:

```bash
xcodebuild test -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=CDF2239B-B46C-4A44-A09E-ED656EF7F9EA' \
  -only-testing:QuestKeeperTests/MonsterArtworkSelectionTests
bash scripts/test-localization.sh
```

Expected: tests pass, gate prints `localization catalog tests passed`.

- [ ] **Step 8: Commit**

```bash
git add QuestKeeperShared/SharedStrings.swift QuestKeeperShared/MonsterArtworkSelection.swift \
  QuestKeeper/Localizable.xcstrings QuestKeeperWidget/Localizable.xcstrings \
  QuestKeeperTests/MonsterArtworkSelectionTests.swift \
  QuestKeeper/Views/QuestRow.swift QuestKeeper/Views/QuestBattleScene.swift \
  QuestKeeperWidget/WidgetDungeonView.swift
git commit -m "feat(i18n): localize monster names"
```

---

### Task 3: Hero appearance labels

**Files:**

- Create: `QuestKeeper/Views/AppStrings.swift`
- Modify: `QuestKeeper/Models/HeroAppearance.swift:5,13-21`
- Modify: `QuestKeeper/Localizable.xcstrings`
- Test: `QuestKeeperTests/HeroAppearanceTests.swift`

**Interfaces:**

- Consumes: the `SharedStrings` pattern from Task 2.
- Produces:
  - `enum AppStrings` — the app-target namespace that Tasks 4 through 8 extend, including `AppStrings.resolve(_ resource: LocalizedStringResource, locale: Locale) -> String`.
  - `HeroGender.title(locale: Locale = .current) -> String` and `HeroHairColor.title(locale: Locale = .current) -> String`, replacing the current `var title: String` on each.

The body-type enum is named `HeroGender` with cases `male` and `female`; `HeroHairColor` has `black`, `brown`, `blue`, `red`. Both are `nonisolated enum … : String, CaseIterable, Hashable, Sendable`, and `HeroAppearance` holds them as `gender` and `hairColor`.

- [ ] **Step 1: Write the failing test**

Add to `QuestKeeperTests/HeroAppearanceTests.swift`:

```swift
@Test("hero appearance labels resolve per locale")
func appearanceLabelsLocalize() {
    #expect(HeroGender.male.title(locale: Locale(identifier: "ko")) == "남성형")
    #expect(HeroGender.male.title(locale: Locale(identifier: "en")) == "Masculine")
    #expect(HeroGender.female.title(locale: Locale(identifier: "en")) == "Feminine")
    #expect(HeroHairColor.black.title(locale: Locale(identifier: "ko")) == "검정")
    #expect(HeroHairColor.black.title(locale: Locale(identifier: "en")) == "Black")
}
```

- [ ] **Step 2: Run it to verify it fails**

Run:

```bash
xcodebuild test -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=CDF2239B-B46C-4A44-A09E-ED656EF7F9EA' \
  -only-testing:QuestKeeperTests/HeroAppearanceTests
```

Expected: compile failure — `title` takes no arguments.

- [ ] **Step 3: Add the catalog entries**

Add to `QuestKeeper/Localizable.xcstrings` only (the widget does not render these):

| Key                             | ko     | en        |
| ------------------------------- | ------ | --------- |
| `hero.appearance.gender.male`   | 남성형 | Masculine |
| `hero.appearance.gender.female` | 여성형 | Feminine  |
| `hero.appearance.hair.black`    | 검정   | Black     |
| `hero.appearance.hair.brown`    | 갈색   | Brown     |
| `hero.appearance.hair.blue`     | 파랑   | Blue      |
| `hero.appearance.hair.red`      | 빨강   | Red       |

That is the complete case list for both enums; no further keys are needed here.

- [ ] **Step 4: Create the app namespace and convert the properties**

Create `QuestKeeper/Views/AppStrings.swift`:

```swift
import Foundation

/// 앱 타깃 문자열 리소스. 키는 `<area>.<element>.<role>` 규칙을 따른다.
nonisolated enum AppStrings {
    static func heroGender(_ gender: HeroGender) -> LocalizedStringResource {
        switch gender {
        case .male: LocalizedStringResource("hero.appearance.gender.male", defaultValue: "남성형")
        case .female: LocalizedStringResource("hero.appearance.gender.female", defaultValue: "여성형")
        }
    }

    static func heroHairColor(_ color: HeroHairColor) -> LocalizedStringResource {
        switch color {
        case .black: LocalizedStringResource("hero.appearance.hair.black", defaultValue: "검정")
        case .brown: LocalizedStringResource("hero.appearance.hair.brown", defaultValue: "갈색")
        case .blue: LocalizedStringResource("hero.appearance.hair.blue", defaultValue: "파랑")
        case .red: LocalizedStringResource("hero.appearance.hair.red", defaultValue: "빨강")
        }
    }

    static func resolve(_ resource: LocalizedStringResource, locale: Locale) -> String {
        var localized = resource
        localized.locale = locale
        return String(localized: localized)
    }
}
```

In `QuestKeeper/Models/HeroAppearance.swift`, replace `HeroGender`'s `var title: String { self == .male ? "남성형" : "여성형" }` with:

```swift
    func title(locale: Locale = .current) -> String {
        AppStrings.resolve(AppStrings.heroGender(self), locale: locale)
    }
```

and replace `HeroHairColor`'s `var title: String { switch self { … } }` with the same shape using `AppStrings.heroHairColor(self)`. The file currently has no `import Foundation`; add one, since `Locale` now appears in both signatures.

- [ ] **Step 5: Fix the call sites in `HeroAppearanceSheet`**

`QuestKeeper/Views/HeroAppearanceSheet.swift` reads `.title` as a property. Change each to `.title()`.

- [ ] **Step 6: Run the tests to verify they pass**

Run:

```bash
xcodebuild test -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=CDF2239B-B46C-4A44-A09E-ED656EF7F9EA' \
  -only-testing:QuestKeeperTests/HeroAppearanceTests
bash scripts/test-localization.sh
```

Expected: both pass.

- [ ] **Step 7: Commit**

```bash
git add QuestKeeper/Views/AppStrings.swift QuestKeeper/Models/HeroAppearance.swift \
  QuestKeeper/Views/HeroAppearanceSheet.swift QuestKeeper/Localizable.xcstrings \
  QuestKeeperTests/HeroAppearanceTests.swift
git commit -m "feat(i18n): localize hero appearance labels"
```

---

### Task 4: Countdown text and plurals

The only task with plural rules. English pluralizes days, hours, and minutes independently, so the compound case needs its components as separate keys.

**Files:**

- Modify: `QuestKeeper/Views/DungeonPresentation.swift:10-18`
- Modify: `QuestKeeper/Views/AppStrings.swift`
- Modify: `QuestKeeper/Localizable.xcstrings`
- Test: `QuestKeeperTests/DungeonPresentationTests.swift:6-16`

**Interfaces:**

- Consumes: `AppStrings.resolve(_:locale:)` from Task 3.
- Produces: `DungeonPresentation.countdownText(deadline: Date, now: Date, locale: Locale = .current) -> String`. Tasks 8 and 9 call it with the default.

- [ ] **Step 1: Rewrite the existing test to assert both locales**

Replace the `countdownText` test in `QuestKeeperTests/DungeonPresentationTests.swift` with:

```swift
@Test("countdown text keeps days, hours, minutes, and past due readable in both locales")
func countdownText() {
    let now = Date(timeIntervalSinceReferenceDate: 820_584_000)
    let ko = Locale(identifier: "ko")
    let en = Locale(identifier: "en")

    #expect(DungeonPresentation.countdownText(deadline: now.addingTimeInterval(2 * 24 * 60 * 60), now: now, locale: ko) == "2일 남음")
    #expect(DungeonPresentation.countdownText(deadline: now.addingTimeInterval(3 * 60 * 60 + 20 * 60), now: now, locale: ko) == "3시간 20분 남음")
    #expect(DungeonPresentation.countdownText(deadline: now.addingTimeInterval(15 * 60), now: now, locale: ko) == "15분 남음")
    #expect(DungeonPresentation.countdownText(deadline: now.addingTimeInterval(30), now: now, locale: ko) == "마감 임박")
    #expect(DungeonPresentation.countdownText(deadline: now.addingTimeInterval(-60), now: now, locale: ko) == "마감 임박")

    #expect(DungeonPresentation.countdownText(deadline: now.addingTimeInterval(24 * 60 * 60), now: now, locale: en) == "1 day left")
    #expect(DungeonPresentation.countdownText(deadline: now.addingTimeInterval(2 * 24 * 60 * 60), now: now, locale: en) == "2 days left")
    #expect(DungeonPresentation.countdownText(deadline: now.addingTimeInterval(60 * 60 + 60), now: now, locale: en) == "1 hour 1 minute left")
    #expect(DungeonPresentation.countdownText(deadline: now.addingTimeInterval(3 * 60 * 60 + 20 * 60), now: now, locale: en) == "3 hours 20 minutes left")
    #expect(DungeonPresentation.countdownText(deadline: now.addingTimeInterval(15 * 60), now: now, locale: en) == "15 minutes left")
    #expect(DungeonPresentation.countdownText(deadline: now.addingTimeInterval(30), now: now, locale: en) == "Due now")
}
```

- [ ] **Step 2: Run it to verify it fails**

Run:

```bash
xcodebuild test -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=CDF2239B-B46C-4A44-A09E-ED656EF7F9EA' \
  -only-testing:QuestKeeperTests/DungeonPresentationTests
```

Expected: compile failure — `countdownText` has no `locale` parameter.

- [ ] **Step 3: Add the catalog entries**

Add to `QuestKeeper/Localizable.xcstrings`. `countdown.dueNow` is a plain entry; the other four use plural variations on `en` and a single `other` category on `ko`. The compound hour-and-minute string is assembled from `countdown.hours` and `countdown.minutes` joined by a space, so `countdown.hours` carries no "left" suffix while `countdown.minutes` does.

| Key                   | ko            | en (`one`)       | en (`other`)      |
| --------------------- | ------------- | ---------------- | ----------------- |
| `countdown.dueNow`    | 마감 임박     | Due now          | —                 |
| `countdown.days`      | %lld일 남음   | %lld day left    | %lld days left    |
| `countdown.hours`     | %lld시간      | %lld hour        | %lld hours        |
| `countdown.hoursOnly` | %lld시간 남음 | %lld hour left   | %lld hours left   |
| `countdown.minutes`   | %lld분 남음   | %lld minute left | %lld minutes left |

`countdown.hours` is the compound's first fragment and deliberately carries no suffix. `countdown.hoursOnly` is the standalone form, used when the minute remainder is zero so an exact hour boundary reads "3 hours left" rather than "3 hours 0 minutes left".

A plural entry has this shape:

```json
    "countdown.days" : {
      "localizations" : {
        "en" : {
          "variations" : {
            "plural" : {
              "one" : { "stringUnit" : { "state" : "translated", "value" : "%lld day left" } },
              "other" : { "stringUnit" : { "state" : "translated", "value" : "%lld days left" } }
            }
          }
        },
        "ko" : {
          "variations" : {
            "plural" : {
              "other" : { "stringUnit" : { "state" : "translated", "value" : "%lld일 남음" } }
            }
          }
        }
      }
    }
```

- [ ] **Step 4: Add the resources to `AppStrings`**

Append to `QuestKeeper/Views/AppStrings.swift`:

```swift
nonisolated extension AppStrings {
    static let countdownDueNow = LocalizedStringResource("countdown.dueNow", defaultValue: "마감 임박")

    static func countdownDays(_ days: Int) -> LocalizedStringResource {
        LocalizedStringResource("countdown.days", defaultValue: "\(days)일 남음")
    }

    static func countdownHours(_ hours: Int) -> LocalizedStringResource {
        LocalizedStringResource("countdown.hours", defaultValue: "\(hours)시간")
    }

    static func countdownMinutes(_ minutes: Int) -> LocalizedStringResource {
        LocalizedStringResource("countdown.minutes", defaultValue: "\(minutes)분 남음")
    }
}
```

- [ ] **Step 5: Rewrite `countdownText`**

Replace the body in `QuestKeeper/Views/DungeonPresentation.swift`:

```swift
    static func countdownText(deadline: Date, now: Date, locale: Locale = .current) -> String {
        let remaining = deadline.timeIntervalSince(now)
        guard remaining >= 60 else {
            return AppStrings.resolve(AppStrings.countdownDueNow, locale: locale)
        }

        let minutes = Int(remaining) / 60
        if minutes >= 1440 {
            return AppStrings.resolve(AppStrings.countdownDays(minutes / 1440), locale: locale)
        }
        if minutes >= 60 {
            let hours = AppStrings.resolve(AppStrings.countdownHours(minutes / 60), locale: locale)
            let rest = AppStrings.resolve(AppStrings.countdownMinutes(minutes % 60), locale: locale)
            return "\(hours) \(rest)"
        }
        return AppStrings.resolve(AppStrings.countdownMinutes(minutes), locale: locale)
    }
```

- [ ] **Step 6: Run the tests to verify they pass**

Run:

```bash
xcodebuild test -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=CDF2239B-B46C-4A44-A09E-ED656EF7F9EA' \
  -only-testing:QuestKeeperTests/DungeonPresentationTests
bash scripts/test-localization.sh
```

Expected: both pass. If the compound case renders with a doubled space or a missing one, fix the join in Step 5 rather than the expectation.

- [ ] **Step 7: Commit**

```bash
git add QuestKeeper/Views/DungeonPresentation.swift QuestKeeper/Views/AppStrings.swift \
  QuestKeeper/Localizable.xcstrings QuestKeeperTests/DungeonPresentationTests.swift
git commit -m "feat(i18n): localize countdown text with English plural rules"
```

---

### Task 5: Battle resolution accessibility values

**Files:**

- Modify: `QuestKeeper/Views/QuestBattleResolution.swift`
- Modify: `QuestKeeper/Views/AppStrings.swift`
- Modify: `QuestKeeper/Localizable.xcstrings`
- Test: `QuestKeeperTests/QuestBattleResolutionTests.swift:50-52`

**Interfaces:**

- Consumes: `AppStrings.resolve(_:locale:)` from Task 3.
- Produces: `QuestBattleResolution.accessibilityValue(for phase: QuestBattlePhase, locale: Locale = .current) -> String`.

`QuestBattlePhase` has four cases. `.idle` returns `""` today and must keep returning a literal empty string — an empty accessibility value is what silences VoiceOver between battles, so it gets no catalog key. Only the other three are localized.

- [ ] **Step 1: Rewrite the existing test to assert both locales**

Replace the three assertions at `QuestKeeperTests/QuestBattleResolutionTests.swift:50-52` with:

```swift
    let ko = Locale(identifier: "ko")
    let en = Locale(identifier: "en")

    #expect(QuestBattleResolution.accessibilityValue(for: .windUp, locale: ko) == "공격 준비 중")
    #expect(QuestBattleResolution.accessibilityValue(for: .striking, locale: ko) == "공격 중")
    #expect(QuestBattleResolution.accessibilityValue(for: .defeated, locale: ko) == "승리 처리 중")

    #expect(QuestBattleResolution.accessibilityValue(for: .windUp, locale: en) == "Winding up")
    #expect(QuestBattleResolution.accessibilityValue(for: .striking, locale: en) == "Striking")
    #expect(QuestBattleResolution.accessibilityValue(for: .defeated, locale: en) == "Claiming victory")

    #expect(QuestBattleResolution.accessibilityValue(for: .idle, locale: ko).isEmpty)
    #expect(QuestBattleResolution.accessibilityValue(for: .idle, locale: en).isEmpty)
```

- [ ] **Step 2: Run it to verify it fails**

Run:

```bash
xcodebuild test -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=CDF2239B-B46C-4A44-A09E-ED656EF7F9EA' \
  -only-testing:QuestKeeperTests/QuestBattleResolutionTests
```

Expected: compile failure — no `locale` parameter.

- [ ] **Step 3: Add the catalog entries**

Add to `QuestKeeper/Localizable.xcstrings`:

| Key                    | ko           | en               |
| ---------------------- | ------------ | ---------------- |
| `a11y.battle.windUp`   | 공격 준비 중 | Winding up       |
| `a11y.battle.striking` | 공격 중      | Striking         |
| `a11y.battle.defeated` | 승리 처리 중 | Claiming victory |

`.idle` gets no key.

- [ ] **Step 4: Add the resources and the `locale` parameter**

Append to `QuestKeeper/Views/AppStrings.swift`:

```swift
nonisolated extension AppStrings {
    static let a11yBattleWindUp = LocalizedStringResource("a11y.battle.windUp", defaultValue: "공격 준비 중")
    static let a11yBattleStriking = LocalizedStringResource("a11y.battle.striking", defaultValue: "공격 중")
    static let a11yBattleDefeated = LocalizedStringResource("a11y.battle.defeated", defaultValue: "승리 처리 중")
}
```

In `QuestBattleResolution.accessibilityValue`, add `locale: Locale = .current` and rewrite the switch so `.idle` still returns `""` while the other three resolve their resource:

```swift
    static func accessibilityValue(for phase: QuestBattlePhase, locale: Locale = .current) -> String {
        switch phase {
        case .idle: ""
        case .windUp: AppStrings.resolve(AppStrings.a11yBattleWindUp, locale: locale)
        case .striking: AppStrings.resolve(AppStrings.a11yBattleStriking, locale: locale)
        case .defeated: AppStrings.resolve(AppStrings.a11yBattleDefeated, locale: locale)
        }
    }
```

- [ ] **Step 5: Run the tests to verify they pass**

Run:

```bash
xcodebuild test -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=CDF2239B-B46C-4A44-A09E-ED656EF7F9EA' \
  -only-testing:QuestKeeperTests/QuestBattleResolutionTests
bash scripts/test-localization.sh
```

Expected: both pass.

- [ ] **Step 6: Commit**

```bash
git add QuestKeeper/Views/QuestBattleResolution.swift QuestKeeper/Views/AppStrings.swift \
  QuestKeeper/Localizable.xcstrings QuestKeeperTests/QuestBattleResolutionTests.swift
git commit -m "feat(i18n): localize battle resolution accessibility values"
```

---

### Task 6: Notification copy

Notification bodies are deliberately redacted — they never carry a quest title. Preserve that while localizing.

**Files:**

- Modify: `QuestKeeper/Notifications/QuestNotificationPlanner.swift`
- Modify: `QuestKeeper/Views/AppStrings.swift`
- Modify: `QuestKeeper/Localizable.xcstrings`
- Test: `QuestKeeperTests/QuestNotificationServiceTests.swift:43-44`

**Interfaces:**

- Consumes: `AppStrings.resolve(_:locale:)` from Task 3.
- Produces: `QuestNotificationPlanner`'s plan-building entry point gains `locale: Locale = .current`, threaded through to every string it builds — the same injection pattern as Tasks 4, 5, and 7. Read the planner first for its real signature; whatever function the service calls to build requests must accept and forward the locale, so a test can pin it.

Do **not** assert `request.content.title == AppStrings.resolve(AppStrings.notificationDueSoonTitle, …)`. That compares the production value against the same resource that produced it, so it passes even when the resource is wrong. Assert literals against a pinned locale instead.

- [ ] **Step 1: Rewrite the existing test**

`QuestKeeperTests/QuestNotificationServiceTests.swift:43-44` asserts the Korean title and body against the ambient locale. Keep the literals and pin the locale, so the assertion still checks real copy:

```swift
        #expect(request.content.title == "퀘스트 마감 임박")
        #expect(request.content.body == "퀘스트가 곧 마감됩니다")
```

Whatever the service test does to build the request must now pass `locale: Locale(identifier: "ko")` so those literals hold regardless of the test host's language. If the service builds requests through the planner without exposing a locale, add the parameter to the service call path too.

Then add a separate test asserting the copy itself in both locales:

```swift
@Test("due-soon notification copy resolves per locale and carries no quest title")
func notificationCopyLocalizes() {
    let ko = Locale(identifier: "ko")
    let en = Locale(identifier: "en")

    #expect(AppStrings.resolve(AppStrings.notificationDueSoonTitle, locale: ko) == "퀘스트 마감 임박")
    #expect(AppStrings.resolve(AppStrings.notificationDueSoonBody, locale: ko) == "퀘스트가 곧 마감됩니다")
    #expect(AppStrings.resolve(AppStrings.notificationDueSoonTitle, locale: en) == "A quest is due soon")
    #expect(AppStrings.resolve(AppStrings.notificationDueSoonBody, locale: en) == "One of your quests is due soon")
}
```

- [ ] **Step 2: Run it to verify it fails**

Run:

```bash
xcodebuild test -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=CDF2239B-B46C-4A44-A09E-ED656EF7F9EA' \
  -only-testing:QuestKeeperTests/QuestNotificationServiceTests
```

Expected: compile failure — `AppStrings.notificationDueSoonTitle` does not exist.

- [ ] **Step 3: Add the catalog entries**

Read `QuestNotificationPlanner` for the exact current copy of every notification kind, then add a key per string. The due-soon pair:

| Key                          | ko                     | en                             |
| ---------------------------- | ---------------------- | ------------------------------ |
| `notification.dueSoon.title` | 퀘스트 마감 임박       | A quest is due soon            |
| `notification.dueSoon.body`  | 퀘스트가 곧 마감됩니다 | One of your quests is due soon |

Add the deadline-kind keys the same way, under `notification.deadline.*`. Keep every English string free of blame and free of any quest title.

- [ ] **Step 4: Add the resources and resolve them in the planner**

Append the matching `LocalizedStringResource` constants to `QuestKeeper/Views/AppStrings.swift`, then replace each Korean literal in `QuestNotificationPlanner` with `AppStrings.resolve(<resource>, locale: locale)`.

- [ ] **Step 5: Run the tests to verify they pass**

Run:

```bash
xcodebuild test -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=CDF2239B-B46C-4A44-A09E-ED656EF7F9EA' \
  -only-testing:QuestKeeperTests/QuestNotificationServiceTests \
  -only-testing:QuestKeeperTests/QuestNotificationPlannerTests
bash scripts/test-localization.sh
```

Expected: both suites pass.

- [ ] **Step 6: Commit**

```bash
git add QuestKeeper/Notifications/QuestNotificationPlanner.swift QuestKeeper/Views/AppStrings.swift \
  QuestKeeper/Localizable.xcstrings QuestKeeperTests/QuestNotificationServiceTests.swift
git commit -m "feat(i18n): localize notification copy"
```

---

### Task 7: Guided quest draft title

**Files:**

- Modify: `QuestKeeper/Onboarding/OnboardingFlowState.swift`
- Modify: `QuestKeeper/Views/AppStrings.swift`
- Modify: `QuestKeeper/Localizable.xcstrings`
- Test: `QuestKeeperTests/OnboardingFlowStateTests.swift:179`

**Interfaces:**

- Consumes: `AppStrings.resolve(_:locale:)` from Task 3.
- Produces: the guided draft's title becomes locale-resolved. Read the source to see whether the draft is built in a pure function; if so add `locale: Locale = .current` to it, otherwise resolve against `Locale.current` at the call site.

- [ ] **Step 1: Rewrite the existing assertion**

`QuestKeeperTests/OnboardingFlowStateTests.swift:179` asserts `draft.title == "물 한 잔 마시기"`. Replace it with:

```swift
        #expect(draft.title == AppStrings.resolve(AppStrings.onboardingGuidedQuestTitle, locale: .current))
```

and add:

```swift
@Test("guided quest title resolves per locale")
func guidedQuestTitleLocalizes() {
    #expect(AppStrings.resolve(AppStrings.onboardingGuidedQuestTitle, locale: Locale(identifier: "ko")) == "물 한 잔 마시기")
    #expect(AppStrings.resolve(AppStrings.onboardingGuidedQuestTitle, locale: Locale(identifier: "en")) == "Drink a glass of water")
}
```

- [ ] **Step 2: Run it to verify it fails**

Run:

```bash
xcodebuild test -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=CDF2239B-B46C-4A44-A09E-ED656EF7F9EA' \
  -only-testing:QuestKeeperTests/OnboardingFlowStateTests
```

Expected: compile failure — `AppStrings.onboardingGuidedQuestTitle` does not exist.

- [ ] **Step 3: Add the catalog entry and resource**

| Key                            | ko              | en                     |
| ------------------------------ | --------------- | ---------------------- |
| `onboarding.guidedQuest.title` | 물 한 잔 마시기 | Drink a glass of water |

```swift
nonisolated extension AppStrings {
    static let onboardingGuidedQuestTitle = LocalizedStringResource(
        "onboarding.guidedQuest.title",
        defaultValue: "물 한 잔 마시기"
    )
}
```

- [ ] **Step 4: Resolve it in `OnboardingFlowState`**

Replace the Korean literal with `AppStrings.resolve(AppStrings.onboardingGuidedQuestTitle, locale: locale)`.

- [ ] **Step 5: Run the tests to verify they pass**

Run:

```bash
xcodebuild test -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=CDF2239B-B46C-4A44-A09E-ED656EF7F9EA' \
  -only-testing:QuestKeeperTests/OnboardingFlowStateTests \
  -only-testing:QuestKeeperTests/OnboardingExperimentReportTests
bash scripts/test-localization.sh
```

Expected: both pass. `OnboardingExperimentReportTests:459` asserts the title is _absent_ from a markdown report, so it stays green either way — confirm it does.

- [ ] **Step 6: Commit**

```bash
git add QuestKeeper/Onboarding/OnboardingFlowState.swift QuestKeeper/Views/AppStrings.swift \
  QuestKeeper/Localizable.xcstrings QuestKeeperTests/OnboardingFlowStateTests.swift
git commit -m "feat(i18n): localize the guided quest draft title"
```

---

### Task 8: Dungeon board views

The largest conversion. Split from Tasks 9 and 10 so a reviewer can reject one screen group without blocking the others.

**Files:**

- Modify: `QuestKeeper/Views/HomeDungeonBoardView.swift` (15 literals)
- Modify: `QuestKeeper/Views/QuestListSections.swift` (12)
- Modify: `QuestKeeper/Views/QuestRow.swift` (8)
- Modify: `QuestKeeper/Views/AppStrings.swift`
- Modify: `QuestKeeper/Localizable.xcstrings`

**Interfaces:**

- Consumes: `AppStrings` from Task 3, `MonsterKind.localizedName(locale:)` from Task 2, `DungeonPresentation.countdownText(deadline:now:locale:)` from Task 4.
- Produces: no new API. Later tasks only need `AppStrings` to keep growing by extension.

- [ ] **Step 1: Enumerate the literals**

Run:

```bash
rg -n '"[^"]*[가-힣][^"]*"' QuestKeeper/Views/HomeDungeonBoardView.swift \
  QuestKeeper/Views/QuestListSections.swift QuestKeeper/Views/QuestRow.swift \
  | grep -vE ':[0-9]+: *(///|//)'
```

Expected: 35 lines. Every one of them is converted in this task.

- [ ] **Step 2: Add a catalog entry per literal**

Add each to `QuestKeeper/Localizable.xcstrings` with the Korean literal as `ko` and an English value in the approved voice. Anchors already fixed by the spec:

| Key                      | ko                                              | en                                                       |
| ------------------------ | ----------------------------------------------- | -------------------------------------------------------- |
| `dungeon.empty.title`    | 오늘의 던전이 비었습니다                        | Today's dungeon is empty                                 |
| `dungeon.empty.body`     | 작은 전투 하나를 추가해 시작하세요.             | Add one small battle to get started.                     |
| `dungeon.firstWin.title` | 첫 승리를 시작해볼까요?                         | Ready for your first victory?                            |
| `dungeon.firstWin.body`  | 2분 안에 끝낼 수 있는 작은 전투부터 시작하세요. | Start with a small battle you can finish in two minutes. |
| `dungeon.firstWin.start` | 2분 전투 시작                                   | Start a 2-Minute Battle                                  |
| `focus.section.title`    | 오늘의 핵심 퀘스트                              | Today's key quests                                       |
| `quest.action.complete`  | 완료                                            | Complete                                                 |
| `quest.action.delete`    | 삭제                                            | Delete                                                   |

Interpolated strings become plural entries in the shape shown in Task 4: `focus.progress` (`%lld/%lld 완료` → `%lld of %lld complete`), `quest.remaining.count` (`나머지 퀘스트 %lld개` → `%lld quest remaining` / `%lld quests remaining`), and `a11y.quest.complete` (`%@ 완료` → `Complete %@`).

- [ ] **Step 3: Add a resource per key to `AppStrings`**

Follow the Task 4 form: a `static let` for fixed strings, a `static func` taking the interpolated values for the rest.

- [ ] **Step 4: Replace the call sites**

`Text`, `Button`, and `Label` take `LocalizedStringResource` directly — `Text(AppStrings.dungeonEmptyTitle)`. Accessibility modifiers take `String`, so those become `AppStrings.resolve(AppStrings.a11yQuestComplete(quest.title), locale: .current)`.

- [ ] **Step 5: Verify no Korean literal survives in these three files**

Run:

```bash
rg -n '"[^"]*[가-힣][^"]*"' QuestKeeper/Views/HomeDungeonBoardView.swift \
  QuestKeeper/Views/QuestListSections.swift QuestKeeper/Views/QuestRow.swift \
  | grep -vE ':[0-9]+: *(///|//)' | grep -v 'defaultValue:'
```

Expected: no output. Korean surviving inside `AppStrings` `defaultValue:` arguments is intended and excluded.

- [ ] **Step 6: Run the full suite and the gate**

Run:

```bash
xcodebuild test -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=CDF2239B-B46C-4A44-A09E-ED656EF7F9EA' \
  -only-testing:QuestKeeperTests
bash scripts/test-localization.sh
```

Expected: all tests pass, gate passes.

- [ ] **Step 7: Commit**

```bash
git add QuestKeeper/Views/HomeDungeonBoardView.swift QuestKeeper/Views/QuestListSections.swift \
  QuestKeeper/Views/QuestRow.swift QuestKeeper/Views/AppStrings.swift QuestKeeper/Localizable.xcstrings
git commit -m "feat(i18n): localize the dungeon board views"
```

---

### Task 9: Remaining app views

**Files:**

- Modify: `QuestKeeper/Views/QuestEditor.swift` (13), `QuestKeeper/Views/RecoveryCardView.swift` (11), `QuestKeeper/Views/DailyFocusSelectionSheet.swift` (10), `QuestKeeper/Views/QuestResolutionView.swift` (9), `QuestKeeper/Views/HeroAppearanceSheet.swift` (6), `QuestKeeper/Views/HeroHeader.swift` (5), `QuestKeeper/Views/QuestBattleScene.swift` (2), `QuestKeeper/Views/HeroSprite.swift` (1)
- Modify: `QuestKeeper/QuestKeeperApp.swift` (9), `QuestKeeper/ContentView.swift` (1)
- Modify: `QuestKeeper/Views/AppStrings.swift`
- Modify: `QuestKeeper/Localizable.xcstrings`

**Interfaces:**

- Consumes: everything Tasks 2 through 8 produced.
- Produces: no new API.

- [ ] **Step 1: Enumerate the literals**

Run:

```bash
rg -n '"[^"]*[가-힣][^"]*"' QuestKeeper/ --glob '*.swift' \
  | grep -vE ':[0-9]+: *(///|//)' | grep -v 'defaultValue:' \
  | grep -vE 'HomeDungeonBoardView|QuestListSections|QuestRow|AppStrings'
```

Expected: 67 lines across the ten files above.

- [ ] **Step 2: Add a catalog entry and an `AppStrings` resource per literal**

Same form as Task 8. The elder-guide chunking prompt from `DESIGN.md` is one of these:

| Key                     | ko                                   | en                                                      |
| ----------------------- | ------------------------------------ | ------------------------------------------------------- |
| `quest.editor.tooLarge` | 너무 큰 퀘스트예요. 작게 쪼개볼까요? | That's a big quest. Want to break it into smaller ones? |

- [ ] **Step 3: Replace the call sites**

`Text` / `Button` / `Label` take the resource directly; accessibility modifiers go through `AppStrings.resolve(_:locale:)`.

- [ ] **Step 4: Verify no Korean literal survives in the app target**

Run:

```bash
rg -n '"[^"]*[가-힣][^"]*"' QuestKeeper/ --glob '*.swift' \
  | grep -vE ':[0-9]+: *(///|//)' | grep -v 'defaultValue:'
```

Expected: no output.

- [ ] **Step 5: Run the full suite and the gate**

Run:

```bash
xcodebuild test -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=CDF2239B-B46C-4A44-A09E-ED656EF7F9EA' \
  -only-testing:QuestKeeperTests
bash scripts/test-localization.sh
```

Expected: all tests pass, gate passes.

- [ ] **Step 6: Commit**

```bash
git add QuestKeeper/ QuestKeeper/Localizable.xcstrings
git commit -m "feat(i18n): localize the remaining app views"
```

---

### Task 10: Widget views

The widget is a separate bundle with its own catalog, so its keys are declared independently even where they duplicate the app's.

**Files:**

- Modify: `QuestKeeperWidget/WidgetDungeonView.swift` (19), `QuestKeeperWidget/QuestKeeperWidget.swift` (3), `QuestKeeperWidget/CompleteQuestIntent.swift` (1)
- Create: `QuestKeeperWidget/WidgetStrings.swift`
- Modify: `QuestKeeperWidget/Localizable.xcstrings`

**Interfaces:**

- Consumes: `SharedStrings.monsterName(_:)` and `MonsterKind.localizedName(locale:)` from Task 2.
- Produces: `enum WidgetStrings`, the widget-bundle equivalent of `AppStrings`, including its own `resolve(_:locale:)`.

- [ ] **Step 1: Enumerate the literals**

Run:

```bash
rg -n '"[^"]*[가-힣][^"]*"' QuestKeeperWidget/ --glob '*.swift' \
  | grep -vE ':[0-9]+: *(///|//)' | grep -v 'defaultValue:'
```

Expected: 23 lines.

- [ ] **Step 2: Create `WidgetStrings` and add catalog entries**

Create `QuestKeeperWidget/WidgetStrings.swift` mirroring `AppStrings`, including:

```swift
    static func resolve(_ resource: LocalizedStringResource, locale: Locale) -> String {
        var localized = resource
        localized.locale = locale
        return String(localized: localized)
    }
```

`WidgetDungeonView.swift:102` (`오늘의 퀘스트 %lld`) and `:211` (`%@ 레벨 %lld`) are interpolated and need plural entries in the Task 4 shape. `:181` already delegates relative time to `RelativeDateTimeFormatter`, so only its trailing `남음` suffix needs a key — English word order puts the equivalent before the interval, so make the key take the formatted interval as an argument rather than concatenating a suffix.

- [ ] **Step 3: Replace the call sites**

`CompleteQuestIntent`'s literal is an App Intents display title; it takes `LocalizedStringResource` directly.

- [ ] **Step 4: Verify no Korean literal survives in the widget target**

Run:

```bash
rg -n '"[^"]*[가-힣][^"]*"' QuestKeeperWidget/ --glob '*.swift' \
  | grep -vE ':[0-9]+: *(///|//)' | grep -v 'defaultValue:'
```

Expected: no output.

- [ ] **Step 5: Run the widget-facing suites and the gate**

Run:

```bash
xcodebuild test -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=CDF2239B-B46C-4A44-A09E-ED656EF7F9EA' \
  -only-testing:QuestKeeperTests
bash scripts/test-localization.sh
```

Expected: all tests pass, gate passes.

- [ ] **Step 6: Commit**

```bash
git add QuestKeeperWidget/
git commit -m "feat(i18n): localize the widget views"
```

---

### Task 11: Reverse guard and documentation

Locks the work in so a future edit cannot silently reintroduce a hardcoded Korean literal.

**Files:**

- Modify: `scripts/test-localization.sh`
- Modify: `QuestKeeper/Views/AppStrings.swift` (doc comment only)
- Modify: `QuestKeeperTests/HeroAppearanceTests.swift`
- Modify: `DESIGN.md` (Voice section)
- Modify: `CLAUDE.md` (Conventions & Constraints — Language)
- Modify: `docs/specs/018-english-localization.md`

Two deferred minors from the Task 3 review are closed here:

- `AppStrings.swift`'s header comment claims keys are `<area>.<element>.<role>`, but real keys such as `hero.appearance.gender.male` run to four segments. Since Tasks 4-9 pattern-match on this file, correct the comment to say segment count is not fixed.
- `HeroAppearanceTests` asserts only `HeroHairColor.black` among four cases, so a copy-paste slip mapping `brown` to the `black` key would compile and pass. Extend the test to assert every `HeroGender` and `HeroHairColor` case in both locales — iterate `CaseIterable` and assert each resolves to a distinct, non-empty string per locale, plus explicit literals for at least one case per enum.

**Interfaces:**

- Consumes: everything above.
- Produces: `scripts/test-localization.sh` additionally fails on any Korean literal outside a `defaultValue:` argument or a comment.

- [ ] **Step 1: Add the reverse guard to the gate script**

Append to `scripts/test-localization.sh`, before the final status check:

```bash
stray="$(
	rg -n '"[^"]*[가-힣][^"]*"' \
		"${repo_root}/QuestKeeper" "${repo_root}/QuestKeeperShared" "${repo_root}/QuestKeeperWidget" \
		--glob '*.swift' |
		grep -vE ':[0-9]+: *(///|//)' |
		grep -v 'defaultValue:' || true
)"
if [[ -n ${stray} ]]; then
	echo "FAIL: hardcoded Korean literal outside a defaultValue:" >&2
	printf '%s\n' "${stray}" >&2
	status=1
fi
```

- [ ] **Step 2: Make the reverse guard fail before trusting its pass**

```bash
printf '\nprivate let probe = "임시 문자열"\n' >>QuestKeeper/ContentView.swift
bash scripts/test-localization.sh; echo "exit=$?"
git checkout QuestKeeper/ContentView.swift
bash scripts/test-localization.sh; echo "exit=$?"
```

Expected: the first run prints the `FAIL:` line with `ContentView.swift` and `exit=1`; the second prints the pass line and `exit=0`.

- [ ] **Step 3: Update `DESIGN.md`**

In the Voice section, replace `Korean UI is the default.` with a line naming Korean as the source-of-record voice and English as a peer locale, and add the approved English anchors beside the existing Korean `Use:` list. Keep the `Avoid:` list and state that it binds English too.

- [ ] **Step 4: Update `CLAUDE.md`**

The Language bullet reads that Korean user-facing strings are intentional and must not be translated. Rewrite it to say user-facing strings live in the String Catalogs under semantic keys with Korean as `defaultValue`, that Korean comments stay untranslated, and that `scripts/test-localization.sh` is the gate. Add that script to the verification commands.

- [ ] **Step 5: Update the spec**

Record in `docs/specs/018-english-localization.md` that call sites reference `LocalizedStringResource` constants in `AppStrings` / `WidgetStrings` / `SharedStrings` rather than raw keys, and that Korean survives in code as each resource's `defaultValue`. This supersedes the spec's original assumption that a missing key would render raw.

- [ ] **Step 6: Final verification**

Run:

```bash
bash scripts/test-localization.sh
xcodebuild test -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=CDF2239B-B46C-4A44-A09E-ED656EF7F9EA' \
  -only-testing:QuestKeeperTests
trunk fmt DESIGN.md CLAUDE.md docs/specs/018-english-localization.md scripts/test-localization.sh
trunk check DESIGN.md CLAUDE.md docs/specs/018-english-localization.md scripts/test-localization.sh
```

Expected: all green.

- [ ] **Step 7: Manual English pass**

Set the simulator language to English (Settings → General → Language & Region), launch the app, and walk every screen plus both widget sizes. Confirm no Korean text and no raw key such as `dungeon.empty.title` appears anywhere.

- [ ] **Step 8: Commit**

```bash
git add scripts/test-localization.sh DESIGN.md CLAUDE.md docs/specs/018-english-localization.md
git commit -m "feat(i18n): guard against stray Korean literals and document the string layer"
```
