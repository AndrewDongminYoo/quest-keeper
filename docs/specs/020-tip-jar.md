# Tip Jar

Adds an optional tip through StoreKit 2, and the "About" surface that holds it.

## Goal

StoreKit 2 is the last untouched 1st-party boundary in the BLUEPRINT's learning line, sitting beside App Intents, WidgetKit, and UserNotifications.
This spec crosses it with the smallest product that can: a consumable tip that grants nothing.

**This is a learning item, not a revenue item, and it must be judged as one.** The app has zero installs beyond the operator's own, so the bottleneck is distribution rather than price, and no tier structure or placement changes that.
Sizing the work so its worth does not depend on earning anything is the point, not a concession.

A second gap is closed on the way. The app has no surface that states its version, links its privacy policy, or names its source repository, and a tip belongs beside those rather than inside a gameplay screen.

## Non-goals

- **Any form of gating.** No quest cap, no paywalled completion, no feature held behind a purchase. The core stays free in full, and a tip buys nothing — not a cosmetic, not a theme, not a badge.
- **Anything in the miss-to-revive flow.** That moment is the app's emotional core and stays payment-free, matching `DESIGN.md`'s shame-free voice.
- **Entitlements, restore, and subscriptions.** A consumable has no entitlement to query and nothing to restore; see the API note below.
- **Server-side receipt validation.** On-device JWS verification only, which keeps the "no backend" non-goal intact.
- **Persisting how much or how often a user tipped.** Nothing about a tip reaches `Quest`, the derivation layer, or the widget snapshot.
- **Cosmetic products.** Environment pixel art, palette theming, and theme/skin purchases stay deferred — they are a product line for an audience that does not exist yet.

## Product type — consumable, and why it picks the APIs

Three consumables, one per tier:

```plaintext
kr.donminzzi.QuestKeeper.tip.small
kr.donminzzi.QuestKeeper.tip.medium
kr.donminzzi.QuestKeeper.tip.large
```

`Transaction.currentEntitlements` returns non-consumables, active auto-renewable subscriptions, non-renewing subscriptions, and **unfinished** consumables — a consumable that has been finished is gone from it. Since a tip is finished the moment it is verified, it never appears there, so it is the wrong API for this feature and no restore flow exists.

The one case where a tip _would_ show up is the one this spec deliberately creates: a transaction that fails verification is left unfinished, so it stays in `currentEntitlements` and keeps being redelivered until it can be resolved. That is the retry path, not a bug.
The consumable path is:

- `Product.products(for:)` to load the tiers,
- `product.purchase()` for the transaction,
- `Transaction.updates` as a long-running listener for transactions that arrive outside a purchase call (an interrupted purchase, an Ask-to-Buy approval),
- `transaction.finish()` on a **verified** transaction only, which is what removes it from the queue.

**A transaction that fails verification is not finished.** Apple's own sample throws from `checkVerified()` on `.unverified` and never reaches `finish()`, and the rule it follows is "finish only after unlocking the content" — so an app that will not honour an unverified transaction must leave it unfinished. The redelivery that causes is the retry mechanism, not a leak.

Verification goes through `VerificationResult`; an unverified transaction is never trusted and never thanked for.

**`QuestKeeperApp` owns the `Transaction.updates` listener, started at launch and alive for the process.** It must not hang off `AboutSheet`: a listener that only runs while the sheet is open misses an Ask-to-Buy approval or an interrupted purchase that lands later, and an unfinished consumable is re-delivered indefinitely.
This follows the existing rule that activation and launch work belongs on the app, never on `ContentView`.

Choosing non-consumable instead would restore the entitlement and restore-flow APIs but sell only once per user, which defeats a tip jar.

## Layer placement

`QuestKeeper/TipJar/` follows the `Notifications/` shape — a pure part, a protocol seam, and a system implementation behind it:

- `TipJarProduct.swift` — the tier `enum` with its product identifiers and display order, plus `TipJarPolicy`, the pure function that turns a purchase signal into an outcome. No StoreKit import.
- `TipJarStore.swift` — the `TipJarStore` protocol (load, purchase, listen) plus `StoreKitTipJarStore`, which wraps StoreKit.

**The protocol is the test seam.** Inject a fake; never reach for StoreKit in a unit test.
This mirrors `QuestNotificationCenter` / `SystemQuestNotificationCenter` exactly, and for the same reason.

**Verification lives above the seam, not inside the StoreKit wrapper.** The protocol yields a `TipJarPurchaseSignal` carrying whether the transaction verified, rather than a `VerificationResult`, and `TipJarPolicy.outcome(for:)` decides thank-versus-discard from it.
If the wrapper made that decision internally, a fake could never produce an unverified transaction and the test asserting the discard path would pass by construction — reading nothing. Keeping the decision pure is what makes that case testable at all.

**The judgement is pure; the execution stays behind the seam.** `TipJarPolicy.shouldFinish(_:)` decides whether a transaction should be taken off the queue, and `StoreKitTipJarStore` calls it inside `settle(_:)` before awaiting `transaction.finish()`. The protocol therefore needs no finish operation and no transaction handle above it — the layer above never holds a `Transaction`, which is what keeps the seam free of StoreKit types.

Both types are declared `nonisolated`: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` is set project-wide, and a bare `extension` does not inherit the primary type's `nonisolated`, so every extension needs it spelled out too.

## About sheet

`QuestKeeper/Views/AboutSheet.swift`, built on the `HeroAppearanceSheet` pattern: `NavigationStack` + grouped `Form`, `DungeonPalette.stone` row backgrounds, `DungeonPalette.dungeon` behind, a confirmation-action dismiss button.

Content, in order:

1. App name and version, read from the bundle rather than hardcoded.
2. Privacy policy link, matching the URL already in `fastlane/metadata/*/privacy_url.txt`.
3. Source repository link.
4. The tip section: one row per tier, each showing `product.displayPrice` (StoreKit's own localized price string — never a hardcoded currency literal), and a thank-you state after a successful purchase.

When products fail to load, the section states that plainly and offers a retry. It never blocks the rest of the sheet.

## Entry point

An icon-only button in `HeroHeader`, at the trailing end of the HUD line — after the stats and the existing `Spacer`, not beside the hero sprite. The sprite is already the appearance entry point, and putting a second button next to it reads as a second appearance control.

**It must appear in both branches of `ViewThatFits`.** The vertical fallback is what renders on a narrow screen or at large Dynamic Type, and it is the app's only entry to this sheet — dropping it there would remove the surface entirely in exactly the case that needs it most. Put the stats and the button on a shared row inside the `VStack` so the trailing placement carries over.

Two constraints that file already documents apply unchanged:

- **No label text.** The header comment records that a label breaks the one-line HUD, because Korean and English differ too much in width. The icon carries it, and `ViewThatFits` keeps the vertical fallback.
- **The 44pt touch target uses the negative-padding pattern** the appearance button uses, so layout width stays the sprite's while the tap area meets the minimum.

Accessibility follows the label/hint split, not a wrapped label: a `Button` replaces the accessibility label of the view it wraps, so the icon needs its own `accessibilityLabel` plus an `accessibilityIdentifier` for UI tests.

## Strings

Every string is a catalog key under `AppStrings`, Korean as `defaultValue` and English as a peer locale — no literal at a call site.

Voice is shame-free and quest-flavored, consistent with `DESIGN.md`. A tip is framed as buying the hero a potion, never as unlocking or supporting-or-else. Declining is not acknowledged at all; there is no "maybe later" copy to dismiss.

Prices are never written into a string. `displayPrice` owns them.

## Verification

- `bash scripts/test-localization.sh` — new keys must carry both locales and add no stray Korean literal.
- `xcodebuild test -only-testing:QuestKeeperTests` with a fake `TipJarStore`, covering: tier order, identifier construction, a successful purchase reaching the thank-you state, a cancelled purchase leaving no state behind, an unverified transaction being left unfinished and reported as a failure rather than thanked, a load that is missing any tier failing instead of drawing a partial list, and a product-load failure rendering the retry state.
- A `.storekit` configuration file referenced from the scheme, so the sheet can be exercised in the simulator before any App Store Connect product exists.
  The project uses `PBXFileSystemSynchronizedRootGroup` for `QuestKeeper`, `QuestKeeperShared`, `QuestKeeperTests`, and `QuestKeeperUITests`, so new Swift files in those directories need no `project.pbxproj` edit. The `.storekit` file does need a scheme reference, and `QuestKeeper.xcscheme` is checked in under `xcshareddata/xcschemes/`; it lives at the repo root rather than inside a synchronized group, so it is not swept into the app bundle as a resource.
- The persistence guard must still match nothing — no tip state may land on `Quest`.
- **Read the rendered sheet in both locales, at the default and at a large Dynamic Type size.** A tip row carries a label and `displayPrice` on one line, and `test-localization.sh` verifies that a key has a value — never what it looks like on screen. Four English defects have already shipped past every gate in this repo for exactly that reason.

## Privacy disclosure — a release prerequisite

StoreKit talks to Apple, so the app stops being offline-only the moment this ships. Three surfaces claim otherwise and must agree before release:

- `docs/legal/terms-of-service.md` — §2 described the app as a `로컬 전용·오프라인 생산성 앱` operating `계정·서버·동기화 없이`. Corrected in this branch, and its deployed Korean and English translations live in the landing repository alongside the policy.
- `docs/legal/privacy-policy.md` — §1 said "완전한 로컬 전용·오프라인" and §5 said "외부 API 호출이 포함되어 있지 않습니다". Both are corrected in this branch, and §5 now describes what the App Store exchange covers and what Apple, not the developer, receives.
- **The deployed landing copies** at `quest.donminzzi.kr` — the host `fastlane/metadata/*/privacy_url.txt` and the listing doc both name — including the English translation. They live in the separate `quest-keeper-landing` repository, are not updated here, and must be synced before the release goes out.
- **The policy's effective date** (`시행일`) is unchanged _in this branch_ and must be set to the publication date at release. §8 of the policy promises to update it whenever the policy changes, so shipping the new text under `2026-07-25` would break the document's own rule. The date to use is the day the landing copies go up alongside a build that contains the tip jar.

**Both listing locales need an edit too.** An earlier draft of this spec exempted them, which was wrong — it checked only the account/login/ads clause. `fastlane/metadata/en-US/description.txt` and `fastlane/metadata/ko/description.txt` each carry two lines that the tip jar falsifies:

```text
· Fully offline and local: no account, no login, no ads.
· No data collection: everything stays on your device.
```

"no account, no login, no ads" does stay true. "Fully offline" and "everything stays on your device" do not, because opening the About sheet loads products from Apple. Reword both locales before release; the clause about accounts and ads can survive as-is.

`[UNCERTAIN]` The App Store Connect **App Privacy** declaration probably stays "Data Not Collected", because payment information handled solely by Apple is exempt from declaration and this app collects no User ID. That reading comes from a search summary rather than Apple's own page; confirm it in the App Privacy form before submitting.

## Blocked on the operator

- **App Store Connect products.** The three consumables must be created in ASC before a real purchase can be tested; only the operator can do that. Local work proceeds against the `.storekit` file.
- **The In-App Purchase capability on the app target and App ID.** `QuestKeeper.xcodeproj` carries no such entry today — only the App Group is in `QuestKeeper.entitlements` — and a local `.storekit` configuration does not need it, so simulator testing passes while the signed build has no way to transact. Add it in Xcode (which regenerates the provisioning profile) before the first Sandbox or TestFlight purchase.
- **A Sandbox tester account** for an end-to-end purchase on device.
- **The Paid Applications Agreement**, banking, and tax setup, none of which is signed for a free-only account. Verify these on Apple's own pages rather than from recall.
