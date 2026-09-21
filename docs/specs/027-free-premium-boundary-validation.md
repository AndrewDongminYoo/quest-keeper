# Free and Premium Boundary Validation

Tracked as Linear AND-40.
This document updates the validation baseline from branch `docs/and-40-premium-boundary-validation` against the product state observed on 2026-09-21.

## Decision

Keep the optional Tip Jar as the only paid surface.
Defer the proposed Supporter Pack and Local Pro products.
Reject advertisements and server-hosted LLM coaching.
Do not add an account, developer server, or subscription to support this scope.

This is a defer decision for the two premium concepts, not evidence that demand can never emerge.
Reconsideration requires the missing distribution and interview evidence below.

## Evidence Status

App Store Connect access was attempted on 2026-09-21 and stopped at the login screen.
No metric was retrieved from App Store Connect.

| Evidence                                                                                 | Result      |
| ---------------------------------------------------------------------------------------- | ----------- |
| First-time downloads for the latest 30-day and 90-day windows                            | `[UNKNOWN]` |
| Active devices for the latest 30-day and 90-day windows                                  | `[UNKNOWN]` |
| Sessions per active device                                                               | `[UNKNOWN]` |
| Day-one and day-seven retention                                                          | `[UNKNOWN]` |
| Tip Jar product-page views, purchases, proceeds, cancellations, and pending transactions | `[UNKNOWN]` |
| Storefront and app-version filters for those metrics                                     | `[UNKNOWN]` |

The repository does not record completed willingness-to-pay interviews or concept-card results.
Do not infer interview evidence from this spec.

## Current Data Boundary

User-consented aggregate report sharing now exists under `docs/specs/029-user-consented-usage-report-sharing.md`.
Each export requires an explicit user action and destination choice.
The report allowlist excludes quest titles, quest descriptions, quest identifiers, installation identifiers, notification content, and individual event rows.
This user-directed aggregate export does not authorize automatic analytics, raw quest export, a developer endpoint, or a paid data feature.

The product remains local-first rather than absolute local-only because the App Store handles Tip Jar product information and purchases, and a user can deliberately send an aggregate report through the system share sheet.

## Free Core

The following capabilities remain free without usage limits:

- create, view, edit, delete, complete, and retry quests;
- the daily dungeon and its shame-free recovery flow;
- importance, urgency, monster, victory, grave, and weekly-review derivations from local facts;
- local notifications;
- Home Screen widgets and App Shortcuts;
- the Hall of Fame;
- routine quests, shipped customization, and accessibility behavior; and
- local measurement plus the optional user-directed aggregate report export.

A purchase must never appear in quest completion, missed-quest failure, retry-tomorrow, or recovery flows.
Free use must never receive advertisements, reduced reliability, artificial delays, or a degraded emotional tone.

## Candidate Packages

| Package          | Product type                           | User value                                                                                | Purchase surface                                                       | Restore and cancellation                                                                                                                                          | Offline contract                                                                                                   | Decision                                              |
| ---------------- | -------------------------------------- | ----------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------- |
| Existing Tip Jar | Consumable                             | Voluntary support with no unlocked value                                                  | About sheet after value has already been experienced                   | Nothing to restore; user cancellation is silent; pending approval remains visible until resolved                                                                  | Core use remains offline; loading prices and purchasing require the App Store                                      | Retain unchanged                                      |
| Supporter Pack   | Non-consumable                         | One exclusive palette, matching hero style, and supporter badge outside the core loop     | About and customization sheets after a full preview                    | Provide Restore Purchases in both surfaces; cancellation changes nothing; pending and verification failures do not unlock content                                 | A verified purchase remains usable offline; restoring requires the App Store                                       | Defer until the evidence gate passes                  |
| Local Pro        | Auto-renewable subscription hypothesis | Deeper local trends, personalization, and on-device coaching that deliver recurring value | Insights after a free weekly preview, never the daily or recovery loop | Provide Restore Purchases and Manage Subscription; turning off renewal preserves access until the verified expiration; pending and billing states remain explicit | Core use remains offline; premium access is derived from the latest verified signed entitlement and its expiration | Defer because recurring value and demand are unproven |

The Supporter Pack test price is **₩5,500 once**.
This is a concept-test anchor, not an App Store Connect price decision.
The Local Pro test prices are **₩4,400 per month** and **₩33,000 per year**.
These are concept-test anchors chosen to be below the larger general-purpose task managers in the 2026-09-14 Korean storefront check while matching Structured's lowest visible monthly tier.
Every future purchase implementation must render StoreKit's localized `displayPrice` instead of a hardcoded amount.

The Supporter Pack and Local Pro are validation concepts only.
Do not create StoreKit products, entitlements, listing copy, or implementation plans for them from this decision.

## Explicit Exclusions

- No quest-count, completion, notification, widget, or retry limit.
- No payment prompt in quest completion, missed-quest failure, retry-tomorrow, or recovery flows.
- No advertisements or paid advertisement removal.
- No account, CloudKit sync, remote analytics, or developer backend for monetization.
- No server-hosted LLM task splitting or coaching.
- No consumable that changes whether a quest can be completed.
- No subscription whose only value is a static theme or one-time feature set.
- No new paid implementation before a later validation records sufficient evidence.

## Public Market Check

The comparison uses the Korean App Store storefront as viewed on 2026-09-14.
The prices are dated observations rather than recommendations, and App Store prices can change.

| App                                                                                                                                                                                                                  | Public model                                            | Visible boundary or price                                                                                                                                                                                                                                                        | Signal for TODO Slayer                                                                                                        |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| [Things 3](https://apps.apple.com/kr/app/things-3/id904237743)                                                                                                                                                       | Paid upfront                                            | ₩17,000 for the iPhone app; other platform apps are sold separately; Things Cloud sync is described as free                                                                                                                                                                      | A focused task tool can charge once, but this model has no free acquisition path.                                             |
| [Todoist](https://apps.apple.com/kr/app/todoist-to-do-%EB%A6%AC%EC%8A%A4%ED%8A%B8-%ED%94%8C%EB%9E%98%EB%84%88/id572688855)                                                                                           | Free plus subscription                                  | Pro is listed at ₩9,900 monthly or ₩88,000 yearly, with a seven-day Pro trial                                                                                                                                                                                                    | Subscription pricing is supported by broad personal and team productivity value, not cosmetics alone.                         |
| [TickTick](https://apps.apple.com/kr/app/ticktick-%ED%95%A0%EC%9D%BC-%EB%AA%A9%EB%A1%9D-%EC%8A%A4%EC%BC%80%EC%A4%84-%ED%94%8C%EB%9E%98%EB%84%88-%EB%AF%B8%EB%A6%AC%EC%95%8C%EB%A6%BC-%EB%8B%AC%EB%A0%A5/id626144601) | Free plus subscription                                  | Premium is listed at ₩7,700 monthly or ₩77,000 yearly; the description still shows older US-dollar prices                                                                                                                                                                        | Storefront product rows, not copied description prose, must be the price source.                                              |
| [Structured](https://apps.apple.com/kr/app/structured-%EB%8D%B0%EC%9D%BC%EB%A6%AC-%ED%94%8C%EB%9E%98%EB%84%88/id1499198946)                                                                                          | Free plus monthly, yearly, and lifetime Pro             | Free covers planning, inbox, sync, subtasks, focus tools, widgets, and customization; Pro adds calendar and reminder connections, repeating work, AI planning, replanning, and custom notifications; visible offers include ₩4,400 monthly, ₩16,500 yearly, and ₩59,900 lifetime | This is the clearest comparable free-to-Pro boundary, but it includes cloud and AI value that TODO Slayer currently excludes. |
| [Habitica](https://apps.apple.com/kr/app/habitica-gamified-taskmanager/id994882113?platform=ipad)                                                                                                                    | Free plus optional subscription and consumable currency | The Korean storefront lists a one-month subscription at ₩6,000, a yearly subscription at ₩58,000, and gem packs; the official description says the app can be fully enjoyed for free                                                                                             | A gamified task loop can remain complete while support and optional economy purchases coexist.                                |
| [Finch](https://apps.apple.com/kr/app/finch-self-care-pet/id1528595748)                                                                                                                                              | Free plus Finch Plus                                    | The Korean storefront lists multiple Finch Plus prices, but it does not label their durations or a precise free-to-paid feature boundary                                                                                                                                         | A price list without a legible value boundary is not a useful model for TODO Slayer's offer copy.                             |

The market check does not prove demand for TODO Slayer.
It supplies dated anchors and shows that a paid boundary must explain durable value.

## Purchase-State Contract

Any future implementation must cover the following states before release:

| State                | Tip Jar                                                                  | Supporter Pack                                                                | Local Pro                                                                                |
| -------------------- | ------------------------------------------------------------------------ | ----------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| Success              | Thank the user without changing app access                               | Unlock only the named cosmetic set after verification                         | Unlock only named premium insight surfaces while the verified subscription is active     |
| User cancelled       | Return silently to the prior state                                       | Keep the free state and preview                                               | Keep the current entitlement state and free core                                         |
| Pending approval     | Keep an explicit waiting message and accept the later transaction update | Keep preview locked and show a waiting message                                | Keep premium locked unless another verified entitlement is active                        |
| Verification failure | Do not thank or finish the transaction                                   | Do not unlock                                                                 | Do not unlock or extend access                                                           |
| Restore              | Not offered                                                              | Re-evaluate verified entitlements after an explicit restore action            | Re-evaluate verified subscription status after an explicit restore action                |
| Refund or revocation | No lasting entitlement exists                                            | Remove the purchased cosmetic entitlement but preserve a valid free selection | Remove premium access without touching quests or local facts                             |
| Expiration           | Not applicable                                                           | Not applicable                                                                | Return only premium insight surfaces to free mode                                        |
| Offline launch       | Core remains available                                                   | Use the locally available verified entitlement and never block the core       | Evaluate the latest verified entitlement and expiration locally and never block the core |

Apple defines consumables as depleted products, non-consumables as purchases that do not expire, and auto-renewable subscriptions as access that renews until cancellation.
Apple also recommends that subscription apps expose status and an easy path to manage or turn off renewal.
These product-type semantics are why a cosmetic pack uses a non-consumable and why Local Pro cannot become a subscription without recurring value.

## Remaining Validation

### Distribution snapshot

After authenticated App Store Connect access is available, record the requested 30-day and 90-day metrics with their storefront and app-version filters.
Until then, preserve `[UNKNOWN]` rather than substituting repository history or user-shared aggregate reports for App Store Connect distribution data.

### Concept interviews

Recruit five people who use a task, habit, focus, or self-care app at least weekly.
Show the free core with Tip Jar, the free core with Supporter Pack, and the free core with Local Pro in randomized order.
Record each answer before assigning a category.

Ask each participant to explain:

1. what remains free;
2. what the purchase adds;
3. when the offer should appear;
4. whether the price feels too low, reasonable, expensive, or unacceptable;
5. which package they prefer and why;
6. what would stop the purchase; and
7. whether the offer weakens trust in the no-account, no-ad, and local-first promises.

Five interviews provide directional evidence only.
Do not claim an interview result until the raw response table and category counts exist.

## Future Decision Gates

- Keep only the Tip Jar when distribution evidence remains unavailable, fewer than three participants understand either premium concept, or fewer than three prefer one concept.
- Consider planning the Supporter Pack only when at least three participants understand its value, at least three prefer it, nobody expects core quest access to be gated, and current active-device evidence justifies implementation work.
- Reconsider Local Pro only when at least three participants name recurring local value, at least three accept a tested subscription anchor, and the separate on-device technical and quality validation passes.
- Reject or redesign a concept when two or more participants say it weakens trust in the free core, shame-free recovery, or local-first contract.

## Current Result

The free boundary is approved.
The Tip Jar remains the only paid surface.
Supporter Pack and Local Pro remain deferred.
Advertisements and server-hosted LLM coaching are rejected.
All requested App Store Connect metrics remain `[UNKNOWN]`, and no interviews are recorded.

## Sources

- Branch source `docs/and-40-premium-boundary-validation:docs/specs/027-free-premium-boundary-validation.md`
- `README.md`
- `docs/specs/020-tip-jar.md`
- `docs/specs/029-user-consented-usage-report-sharing.md`
- `docs/legal/privacy-policy.md`
- `docs/legal/terms-of-service.md`
- `fastlane/metadata/en-US/description.txt`
- `fastlane/metadata/ko/description.txt`
- [Apple In-App Purchase types](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-types)
- [Apple auto-renewable subscriptions](https://developer.apple.com/app-store/subscriptions/)
- [Things 3 on the Korean App Store](https://apps.apple.com/kr/app/things-3/id904237743)
- [Todoist on the Korean App Store](https://apps.apple.com/kr/app/todoist-to-do-%EB%A6%AC%EC%8A%A4%ED%8A%B8-%ED%94%8C%EB%9E%98%EB%84%88/id572688855)
- [TickTick on the Korean App Store](https://apps.apple.com/kr/app/ticktick-%ED%95%A0%EC%9D%BC-%EB%AA%A9%EB%A1%9D-%EC%8A%A4%EC%BC%80%EC%A4%84-%ED%94%8C%EB%9E%98%EB%84%88-%EB%AF%B8%EB%A6%AC%EC%95%8C%EB%A6%BC-%EB%8B%AC%EB%A0%A5/id626144601)
- [Structured on the Korean App Store](https://apps.apple.com/kr/app/structured-%EB%8D%B0%EC%9D%BC%EB%A6%AC-%ED%94%8C%EB%9E%98%EB%84%88/id1499198946)
- [Habitica on the Korean App Store](https://apps.apple.com/kr/app/habitica-gamified-taskmanager/id994882113?platform=ipad)
- [Finch on the Korean App Store](https://apps.apple.com/kr/app/finch-self-care-pet/id1528595748)
