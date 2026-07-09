# Phase 5 Retrospective

Status: blocked - manual OS-surface verification pending
Source commit: 2ec3ba4c266d61d07df726622e3a0ec1c94b442f

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
- Local notification delivery timing: scheduling and pruning are tested, but Notification Center presentation timing still needs hands-on verification.
- Device signing and App Group provisioning: entitlements and the shared identifier are present, but physical-device provisioning was not verified in this session.

## Accepted Shortcuts

- No CloudKit or account system.
- No recurring quest engine.
- No SpriteKit or polished pixel asset pipeline.
- No interactive widget actions.
- Widget uses an App Group JSON cache instead of opening SwiftData.

## Follow-Up Backlog Recommendation

Recommended next item: manual OS-surface verification sweep for notifications, widget installation, WidgetKit refresh, and App Group behavior.

Reason: the automated gate now covers raw facts and deterministic derivation, but Phase 5 acceptance still depends on manual evidence for OS-controlled surfaces.

## Closeout Decision

- Phase 5 accepted: no
- Phase 5 blocked: yes, pending manual OS-surface verification

Evidence: `QuestKeeperTests` passed with 63 tests, simulator build passed, source guard passed, simulator launch smoke passed, and all manual scenarios are recorded as blocked in `docs/notes/006-phase-5-verification-log.md`.
