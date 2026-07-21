# QuestKeeper Synthetic Retention Baseline

This report uses synthetic fixture data and is not evidence of real user performance.
Fixture version: 1.
Report schema version: 1.
Generated at: 2026-07-13T15:00:00Z.
Time zone: Asia/Seoul.
Reporting week: 2026-07-05T15:00:00Z to 2026-07-12T15:00:00Z, end exclusive.

## Funnel

First value: 3 / 4, 75.0%.
First completion: 2 / 3, 66.7%.
D1 retention: 2 / 4, 50.0%.
D7 retention: 1 / 3, 33.3%.
Weekly active installations: 3.
Weekly repeated completion: 1 / 3, 33.3%.

## Data Quality

Status: complete.
- Duplicate rows: 0.
- Missing scenario keys: 0.
- Forbidden scenario keys: 0.
- Unsupported rows: 0.
- Orphan completions: 0.
- Pre-activation creations: 0.
- Pre-measurement rows: 0.
- Future rows: 0.

## Reproduce

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/RetentionReportTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
```
