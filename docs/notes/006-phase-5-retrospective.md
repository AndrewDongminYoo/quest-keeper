# Phase 5 Retrospective

Status: ready for PR review; quest-list visibility follow-up noted
Source commit: e7323ec72be37b77a401847c655cfefc9acc898e

## Native Boundaries Crossed

- SwiftData raw facts: guarded by a source scan that found no forbidden derived storage fields under `QuestKeeper/Models`.
- Deterministic derivation: covered by integration tests comparing app and widget derivation from the same `QuestSnapshot` facts.
- App activation replay: covered by an integration test that confirms missed-deadline deaths are reported once and the activation clock advances.
- UserNotifications lifecycle: covered by planner and service tests for scheduling, cancellation, reconcile, and delivered notification pruning.
- App Group snapshot bridge: covered by widget payload and snapshot writer tests that preserve raw facts and recover from stale or failed writes.
- WidgetKit timeline rendering: covered at the derivation and payload layer; Home Screen rendering still needs manual OS-surface verification.

## Most Error-Prone Boundary

The app and widget derivation boundary required the most rework.
The late-completion policy had to be made explicit: a quest completed after its deadline is not a victory and is not an active mob, but it remains a same-day daily grave in both app and widget derivation.

## Manual-Only Assumptions

- WidgetKit refresh timing: not proven by unit tests or simulator launch smoke.
- Local notification delivery timing: scheduling and pruning are tested, and user manual check reports notification behavior works.
- Device signing and App Group provisioning: entitlements and the shared identifier are present, but physical-device provisioning was not verified in this session.

## Accepted Shortcuts

- No CloudKit or account system.
- No recurring quest engine.
- No SpriteKit or polished pixel asset pipeline.
- No interactive widget actions.
- Widget uses an App Group JSON cache instead of opening SwiftData.

## Follow-Up Backlog Recommendation

Recommended next item: improve quest list visibility without changing the raw-facts model or lifecycle behavior.

Reason: retry tomorrow and notification behavior are reported working, while the task list itself is harder to scan than the lifecycle surfaces around it.

## Closeout Decision

- Phase 5 accepted: ready for PR review with a known UI visibility follow-up
- Phase 5 blocked: no

Evidence: `QuestKeeperTests` passed with 63 tests, simulator build passed, source guard passed, simulator launch smoke passed, and user manual check reports `내일 도전하기` plus notification behavior work.
