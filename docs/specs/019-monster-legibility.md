# Monster Legibility

Tracked as Linear AND-114.
Makes the rule behind a quest's monster readable from the screen, for a user who skipped onboarding.

## Goal

`mobLevel = importance (stored) × urgency (derived from time remaining)` picks the monster deterministically, and that rule is the app's core mechanic — postpone something and it grows.
The row shows only the result, so a user who did not read the onboarding copy concludes the monster is random, and the mechanic never lands.
A rule that is not read is the same as no rule.

Two things are missing, and they are different problems:

1. **The causal link.** The row already displays all three quantities — the countdown (urgency), `IMP N` (importance), and `Lv N` plus the sprite (the result). What it never shows is that the first two produced the last.
2. **The moment of change.** A monster escalating as its deadline approaches is the clearest possible demonstration of the rule, and it currently happens silently.

This spec addresses (2) with a row marker and (1) with an explanation sheet.

## Non-goals

- Changing monster kinds or balance numbers. `GameBalance` tuning is separate.
- New pixel art.
- Rewriting onboarding copy, or adding an onboarding step.
  The premise of this issue is the user who skips onboarding, so another screen at first launch does not address it — and a new step would land inside the live `and-34-first-value-v1` experiment and change what it measures mid-flight.
- A monster preview that reacts while editing importance in the quest editor.
  It was a candidate in the issue; the marker and the sheet already satisfy the acceptance criteria. Revisit only if they prove insufficient.

## Derivation — escalations while away

`HeroState` gains one field alongside `deathsWhileAway`, computed the same way and from the same inputs:

```swift
let escalationsWhileAway = quests
    .filter { $0.outcome(at: now) == .pending }
    .filter { $0.mobLevel(at: lastOpened) < $0.mobLevel(at: now) }
    .map(\.id)
```

Nothing is stored on `Quest`.
`mobLevel(at:)` is a pure function of `importance` and `urgency(at:)`, so evaluating the same snapshot at two instants is the whole mechanism, and `HeroDerivation.state` stays deterministic in its inputs.

The `.pending` filter matters: completed rows and graves render no monster, so an escalation on one has nothing to mark.

### Why it cannot be derived at render time

`lastOpened` is advanced on activation.
`Activation.swift` is explicit that `reconstructOnActivation` replays against the **previous** value and the caller persists the new one **after** surfacing the result, so a subsequent activation replays nothing.
A marker computed at render time from the stored `lastOpened` would therefore never appear — the value has already been overwritten with `now`.

The escalation set has to ride the same path `deathsWhileAway` does: computed once during the activation replay, then carried as transient state.

### Flow

The existing pipeline already carries exactly this shape for graves.
`escalatedQuestIDs: Set<UUID>` travels beside `newlyMissedQuestIDs`:

```plaintext
reconstructOnActivation  →  ActivationReplayResult
                         →  ContentView
                         →  HomeDungeonBoardView
                         →  QuestListSections
                         →  QuestRow
```

### Lifetime

The marker persists until the next activation replaces it. Nothing is persisted; the set lives in `@State` and is overwritten on the next activation.

**It does not share `newlyMissedQuestIDs`' lifetime, despite sharing its path.**
`pendingDeaths` is cleared by a timer after `GameBalance.mourningDuration` (`ContentView.applyActivationReplay()`), because it drives a one-shot mourning animation that would otherwise latch.
An escalation marker is information, not an animation: it has to survive long enough to be read after the user navigates back to the board, so it takes no timer.
`applyActivationReplay` also returns early when `deaths` is empty, so the escalation assignment must sit outside that guard rather than nested inside it.

Reopening the app twice in one day can mark the same row again if it escalated again in between. That is correct behavior, not a defect.

## Row marker

A small pill above the `Lv N` badge, shaped like `ImportancePip` so no new visual language is introduced, tinted with the row's urgency tone.

```plaintext
마감이 다가와 세졌어요        ← marker
            Lv 5
             🐉
```

**The copy names the cause, not the effect.**
"한 단계 올라감" reports what happened; "마감이 다가와 세졌어요" reports why, which is the thing the issue asks for.
English: `Stronger, due soon` — shortened after the rendered check.
`Stronger — deadline is closer` clipped to `Stronger — deadl…` in the 100pt trailing column, the same width defect as PR #32's `Edit key…`.
The Korean value renders whole, so only the English one changed.

Both readings state causation and neither assigns blame, satisfying the `DESIGN.md` Voice prohibitions in both locales.

## Explanation sheet

### Entry point

`MonsterGlyph`, not the `Lv N` badge — the sprite is what a user forms the question about, while `Lv` is already a summarized result.

Two constraints:

- **The row's tap is already taken.** `SwipeableQuestRow` binds `onTapGesture` to open the editor and carries a `simultaneousGesture(DragGesture)` for swipe-to-reveal.
  A `Button` around the glyph should take priority, but this is not asserted — it is verified by test, because losing swipe-to-reveal would cost more than the marker gains.
- **34pt is below the 44pt touch target.** `HeroHeader` already solves this for the hero sprite: inner padding to reach 44pt, negative outer padding to restore the layout width. Reuse that.

### Content

A `.medium` detent sheet, matching `HeroAppearanceSheet`.

```plaintext
이 몬스터는 왜 오크인가요

  중요도 높음   ×   마감 3시간 남음   →   Lv 3 · 오크
  (직접 정한 값)     (시간이 정함)

몬스터는 이렇게 정해집니다
  Lv 0-1  슬라임 · 박쥐 · 버섯
  Lv 2-3  해골 · 오크 · 미믹
  Lv 4-5  드래곤 · 골렘 · 리치

  중요도는 퀘스트를 만들 때 정하고, 마감까지 남은 시간은 계속 움직입니다.
  그래서 같은 퀘스트라도 마감이 다가오면 몬스터가 바뀝니다.
```

The concrete case comes first and the general rule second, because the sheet is opened by someone already holding a specific question.

The tier table renders from `MonsterArtworkSelection.family(forMobLevel:)` and the `MonsterKind` cases rather than from a copy of the mapping, so tuning `GameBalance.maxMobLevel` or the families keeps the sheet correct without a documentation edit.

### Why a sheet rather than an onboarding step

The sheet is reachable whenever the question arises, not once at first launch when it has not.
It also touches neither the running experiment nor the append-only measurement models — an onboarding step would need a new `RetentionEvent` name to know it had been seen.

## Verification

- **Derivation** — `HeroDerivation` unit tests: only quests whose level rose are collected; completed quests and graves are excluded; `lastOpened == now` yields an empty set; the function stays deterministic.
- **Marker** — a fixture whose level rises across the two instants renders the pill.
- **Tap** — a UI test asserting the sheet opens _and_ that swipe-to-reveal still works on the same row. The second assertion is the point.
- **Localization** — new keys in both catalogs, `scripts/test-localization.sh`, and **both locales' screenshots read by eye**.
  The sheet is wide and English runs longer than Korean; the `Edit key…` truncation in PR #32 came from exactly this shape, and no gate reads layout.
- **Guard** — the persist-facts-derive-state check in `CLAUDE.md` must still return nothing.
