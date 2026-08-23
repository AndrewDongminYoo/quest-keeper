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

`Transaction.currentEntitlements` returns transactions for non-consumables and auto-renewable subscriptions **only**, so it is the wrong API here and no restore flow exists.
The consumable path is:

- `Product.products(for:)` to load the tiers,
- `product.purchase()` for the transaction,
- `Transaction.updates` as a long-running listener for transactions that arrive outside a purchase call (an interrupted purchase, an Ask-to-Buy approval),
- `transaction.finish()` on every verified transaction, which is what removes it from the queue.

Verification goes through `VerificationResult`; an unverified transaction is finished without thanking the user, never trusted.

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
- `xcodebuild test -only-testing:QuestKeeperTests` with a fake `TipJarStore`, covering: tier order, identifier construction, a successful purchase reaching the thank-you state, a cancelled purchase leaving no state behind, an unverified transaction being finished without thanks, and a product-load failure rendering the retry state.
- A `.storekit` configuration file referenced from the scheme, so the sheet can be exercised in the simulator before any App Store Connect product exists.
  The project uses `PBXFileSystemSynchronizedRootGroup` for `QuestKeeper`, `QuestKeeperShared`, `QuestKeeperTests`, and `QuestKeeperUITests`, so new Swift files in those directories need no `project.pbxproj` edit. The `.storekit` file does need a scheme reference, and `QuestKeeper.xcscheme` is checked in under `xcshareddata/xcschemes/`; it lives at the repo root rather than inside a synchronized group, so it is not swept into the app bundle as a resource.
- The persistence guard must still match nothing — no tip state may land on `Quest`.
- **Read the rendered sheet in both locales, at the default and at a large Dynamic Type size.** A tip row carries a label and `displayPrice` on one line, and `test-localization.sh` verifies that a key has a value — never what it looks like on screen. Four English defects have already shipped past every gate in this repo for exactly that reason.

## Blocked on the operator

- **App Store Connect products.** The three consumables must be created in ASC before a real purchase can be tested; only the operator can do that. Local work proceeds against the `.storekit` file.
- **A Sandbox tester account** for an end-to-end purchase on device.
- **The Paid Applications Agreement**, banking, and tax setup, none of which is signed for a free-only account. Verify these on Apple's own pages rather than from recall.
