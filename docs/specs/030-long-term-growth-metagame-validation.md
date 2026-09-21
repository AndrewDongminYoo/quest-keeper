# Spec 030 — Long-Term Growth Metagame Validation

Status: decision recorded
Tracks: AND-39
Dependency: Linear AND-33 was `Done` when checked on 2026-09-21.

## Goal

Choose one low-cost, shame-free long-term acknowledgement concept to validate before adding a growth metagame.
Keep the current quest lifecycle, optional Tip Jar boundary, and current-state victory semantics intact.

## Decision

Prototype only a victory-derived hero rank.
The rank is a display-only tier derived at read time from `HeroState.totalVictories`.
It acknowledges current on-time completions without changing quest rules, combat strength, rewards, access, or purchases.

Defer a permanent victory collection.
It would require a new persisted archive or equivalent retention of victory facts after a Quest is deleted or ceases to be a victory.
That is a deliberate change to the current deletion semantics and is not a low-cost follow-up.

Reject progression-unlocked cosmetics for this decision.
They would turn completion into a route to withheld appearance content instead of keeping the existing choices presentation-only.
They create a credible risk of grind or forced progression, and selling an unlock would also conflict with the Tip Jar rule that optional payment grants nothing.

## Low-Cost Prototype Cards

Use these static text cards to compare the concepts before any production implementation.
They intentionally omit animation, persistence, analytics, and purchase behavior.

### A: Victory-Derived Hero Rank

```plaintext
용사의 등급
견습 용사
현재 승리 12회

현재 남아 있는 정시 완료 퀘스트로 계산해요.
등급은 보상이나 기능을 잠그지 않아요.
```

### B: Permanent Victory Collection

```plaintext
승리의 기록
지금까지 모은 승리 12개

완료한 퀘스트를 삭제해도 이 기록은 남아요.
```

### C: Progression-Unlocked Cosmetics

```plaintext
다음 외형
승리 20회에 새로운 망토가 열려요.
현재 12 / 20
```

The cards make the semantic trade-off explicit: A reflects current victory state, B preserves history after deletion, and C withholds an appearance choice until more completions occur.
They are comparison artifacts only and do not imply measured preference.

## Concept Comparison

| Concept                        | User value                                                                                  | Implementation cost                                                                                                               | Monetization fit                                                                                           | Decision             |
| ------------------------------ | ------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- | -------------------- |
| Victory-derived hero rank      | A visible acknowledgement of current on-time completions without a new task or reward loop. | Low: a later pure display can read the existing `HeroState.totalVictories` value.                                                 | Compatible only as a non-commercial acknowledgement; it must grant no purchasable or gameplay benefit.     | Follow-up prototype. |
| Permanent victory collection   | May preserve a durable record of past victories after deletion.                             | Higher: it needs new persistence, retention rules, and tests for deletion and state changes.                                      | Not a reason to sell access or preservation.                                                               | Deferred.            |
| Progression-unlocked cosmetics | May offer visible variety, but makes completion a requirement for appearance choices.       | Higher: unlock state, thresholds, copy, and accessibility coverage would be needed alongside the existing appearance preferences. | Incompatible with the optional no-reward Tip Jar boundary if purchase or progression determines cosmetics. | Rejected.            |

The cost and user-value entries are design assessments, not measured participant results.
No user preference, retention effect, or willingness-to-pay claim has been verified for any concept.

## Constraints

- Do not add random rewards, currencies, streak loss, content gates, or paid power.
- Do not change a Quest's deadline, outcome, completion, deletion, retry, notification, widget, or recovery behavior.
- Do not add rank, collection, unlock, or reward state to `Quest`, `QuestSnapshot`, SwiftData, widget payloads, or retention models.
- Preserve the existing hero appearance choices as presentation-only preferences that do not affect rewards or combat strength.
- Preserve current-state semantics: a late completion is not a victory, and a deleted Quest is absent from current victory-derived surfaces.
- Keep the Tip Jar optional and reward-free; a tip buys no cosmetic, badge, feature, completion outcome, or other entitlement.

## Evidence Boundary

Repository-supported evidence:

- Spec 012 defines first quest creation and first completion as separate funnel steps, records only the approved local event dictionary, and forbids victory count from retention events.
- Spec 017 excludes inventory, unlocks, achievements, currencies, shops, rarity, and monetized skins, and states that appearance choices do not affect quest rules, combat strength, or rewards.
- Spec 020 defines the Tip Jar as a consumable tip that grants nothing, with no gating, cosmetic products, entitlements, or persisted tip state.
- Spec 021 derives Hall of Fame entries from the current Quest store and removes an entry immediately when its Quest is deleted or stops being a victory.
- Spec 026 derives its figures at read time from the current Quest store, treats active days as explicitly not a streak, and accepts that deleted victories disappear retroactively.

Unverified claims:

- There is no participant evidence that a hero rank feels motivating, understandable, or shame-free.
- There is no participant evidence that a permanent collection is wanted after deletion.
- There is no participant evidence that cosmetics would improve retention or that any participant would pay for them.
- There is no willingness-to-pay evidence for the Tip Jar or for any metagame concept.

The existing deterministic retention fixture is synthetic and is not evidence of real user performance.
It must not be used to infer demand for rank, collection, cosmetics, or payment.

## Follow-Up Validation

Run a moderated qualitative check with three to five real participants before approving production work.
Do not describe this protocol as completed until those sessions have occurred and their notes have been reviewed.

For each participant:

1. Show the existing victory counter and explain that a rank would be calculated only from current on-time victories.
2. Ask the participant to describe what they think changes when a quest is completed late or deleted.
3. Show a static rank concept with no reward, unlock, purchase, or gameplay effect, then ask whether it feels clear and optional.
4. Contrast it verbally with a permanent collection and progression-unlocked cosmetics, then ask which, if any, would improve their experience and why.
5. Ask separately whether any appearance or acknowledgement should ever be paid, while recording the answer as exploratory feedback rather than willingness-to-pay evidence.

Record de-identified session notes for comprehension, perceived pressure, and stated preference.
Do not add product analytics, new persistence, or a payment prompt for this validation.

Advance the rank prototype only if most participants can correctly explain its current-state behavior and no participant reports that it makes missed, late, or deleted quests feel punitive.
If comprehension fails or pressure is reported, keep all three concepts out of production and revisit the decision with the notes.

## Follow-Up Scope

The only possible next implementation is a later pure `totalVictories`-derived display prototype.
It may render a rank label or tier beside an existing hero or victory surface, but it must store no rank state and grant no reward, cosmetic, content access, currency, streak protection, or power.

This document authorizes neither a permanent collection nor progression-unlocked cosmetics.
It also authorizes no production analytics, migration, new persistence, StoreKit change, or monetization experiment.

## Sources

- `docs/specs/012-core-retention-funnel.md` — canonical first-value and completion funnel, local-only measurement contract, and synthetic-fixture limitation.
- `docs/specs/017-combat-assets-and-hero-customization.md` — presentation-only appearance behavior and excluded unlock, currency, shop, rarity, and monetized-skin systems.
- `docs/specs/020-tip-jar.md` — optional consumable tip that grants nothing, with no gating or cosmetic products.
- `docs/specs/021-hall-of-fame.md` — current-store victory derivation and deletion-removal behavior.
- `docs/specs/026-weekly-review.md` — `HeroState.totalVictories` victory predicate, no-streak rule, and current-store deletion semantics.
- [Linear AND-33](https://linear.app/andrewdongminyoo/issue/AND-33) — status observed as `Done` on 2026-09-21.
