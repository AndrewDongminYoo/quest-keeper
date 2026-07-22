# QuestKeeper Synthetic Onboarding Experiment Baseline

> Synthetic fixture output only. This is not real-user evidence.

## Cohort

- Experiment: and-34-first-value-v1.
- Start: 2026-07-01T15:00:00Z.
- End (exclusive): 2026-07-08T15:00:00Z.
- As of: 2026-07-12T15:00:00Z.
- Time zone: Asia/Seoul.

## Control

- Funnel: 2 exposed -> 2 creation started -> 1 first value -> 1 first completion.
- Onboarding completion within two minutes: 1 / 2, 50.0%.
- First success within two minutes: 0 / 2, 0.0%.
- First-quest completion: 1 / 1, 100.0%.
- Median time to first value: 60.0 seconds.
- D1: 1 / 2, 50.0%.
- D7: 1 / 1, 100.0%.

## Guided

- Funnel: 2 exposed -> 2 creation started -> 2 first value -> 1 first completion.
- Onboarding completion within two minutes: 1 / 2, 50.0%.
- First success within two minutes: 1 / 2, 50.0%.
- First-quest completion: 1 / 2, 50.0%.
- Median time to first value: 120.0 seconds.
- D1: 1 / 2, 50.0%.
- D7: 0 / 1, 0.0%.
- Guided deferral: 1 / 2, 50.0%.

## Data Quality

- Status: complete.
- Duplicate assignments: 0.
- Conflicting assignments: 0.
- Missing exposures: 0.
- Unsupported rows: 0.
- Ordering failures: 0.
- Cross-installation mismatches: 0.
- Duplicate events: 0.

## Reproduce

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,id=CDF2239B-B46C-4A44-A09E-ED656EF7F9EA' -only-testing:QuestKeeperTests/OnboardingExperimentReportTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
```
