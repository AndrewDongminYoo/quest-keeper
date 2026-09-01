# Weekly Review

Tracked as Linear AND-37.

## Goal

Once a week the board opens with a short account of the week that just ended and one action that starts the next one.
The account leads with what the user did, never with what they missed, and the action is a single tap into the existing quest editor.

## Current-State Semantics

The review summarises the **previous** calendar week — the week containing `now` minus one week, resolved through the supplied `Calendar` so the week's first weekday and the local time zone are the user's.
It is derived from the current Quest store at read time and stores nothing.

Three figures, all computed from the same victory predicate `HeroState.totalVictories` already uses (`QuestSnapshot.outcome(at:) == .victory`):

- **Victories** — quests whose `completedAt` falls inside the previous week.
- **Active days** — the count of distinct local calendar days inside that week that hold at least one such completion. This is the "꾸준함" figure; it is a count of days, never a streak, so a missed day cannot reset anything to zero.
- **Change** — this week's victory count minus the week before it. Reported as a signed integer; the presentation decides how to say it.

A quest completed after its deadline is a grave, so it does not count, exactly as in the Hall of Fame.
A quest deleted since the week ended is simply absent; there is no archive.

Late-completed and deleted quests being invisible means the figures can move retroactively.
That is the same current-state semantics the rest of the app has, and it is deliberate.

## Presentation

A card in the board's existing `LazyVStack`, in the same position class as `RecoveryCardView` and `DailyFocusRecommendationCard` — not a new navigation destination and not a sheet.

Acknowledgement is one `@AppStorage` preference holding **the start instant of the week the card last reviewed**, alongside the existing `lastOpenedTIRD` and hero-appearance preferences.
It names what was shown rather than when it was shown, so the card appears exactly when the previous week's start differs from the stored one.
No quest, snapshot, or `@Model` gains a field.

Two consequences follow, and both are intended:

- After an absence of several weeks the card reviews the week that just ended, once, and the weeks in between are never shown. A review of a week the user has forgotten is worse than no review, and the weeks in between are exactly the ones the recovery loop already speaks to.
- The card is suppressed while `RecoveryCardView` is presented, the same guard `DailyFocusRecommendationCard` already uses, and every recovery action acknowledges the reviewed week on its way out. Returning after a long absence therefore gets the recovery card alone, and the week the user was away for is skipped rather than summarised — otherwise the weekly card would take the recovery card's place in the same render and ask for a quest the user has just been asked for.

The card carries, in this order:

1. one line naming the week it covers;
2. the three figures, achievements first;
3. the primary action, which opens the quest editor the board already presents;
4. a secondary dismiss action.

Both actions write the same acknowledgement, so the dismiss buys nothing the primary does not — except an exit.
It stays for that reason alone: a card that can only be cleared by creating a quest is a surface that holds the board hostage to an action, and this app does not do that to a user who missed a deadline, so it will not do it to one who does not want a next-week goal.

A week with no victories gets its own copy: it states that the next week is open and offers the same primary action.
It must not name the user as having failed, missed, or lost anything — `DESIGN.md` Voice governs, as it does for graves.
The change figure is omitted rather than shown as a negative number when it would be the only thing the card says about a quiet week.

## Accessibility And Localization

Every string is a semantic key in `AppStrings` with a Korean `defaultValue` and an English peer, per the String Catalog rule.
The figures are read as a single accessibility element with a sentence that names each number, because three bare numerals read out of context are not usable.
Both actions carry a stable accessibility identifier.
The card must survive Dynamic Type without clipping; long localized labels wrap.

## Non-Goals

- No new persisted model, no history archive, no migration.
- No charts, no trend graph, no Swift Charts dependency.
- No per-quest list inside the card; the Hall of Fame already owns "which victories".
- No selection of several goals for the next week; the daily-focus loop owns multi-quest selection, and this card's job is to start one.
- No notification, no widget surface, and no retention event in this version.

## Verification

- A Swift Testing suite over the derivation covers: an empty week, a week with victories on one day, victories spread over several days, a late completion excluded, a positive and a negative change, and a week boundary resolved through a non-Gregorian first weekday and a non-UTC time zone.
- The acknowledgement rule is covered by its own cases: an unacknowledged week shows the card, an acknowledged one does not, a new week shows it again, and a jump of several weeks shows it once for the week that just ended rather than once per skipped week.
- A UI test opens the board with a seeded previous week and confirms the card, its figures, and that the primary action reaches the quest editor.
- `scripts/test-localization.sh` passes, so every new key exists in both catalogs with no stray literal.
