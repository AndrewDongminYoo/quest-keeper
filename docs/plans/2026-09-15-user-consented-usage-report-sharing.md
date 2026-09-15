# Implement User-Consented Usage Report Sharing

## Contract

Implement `docs/specs/029-user-consented-usage-report-sharing.md` for Linear issue AND-176.
Use the current workspace on `feat/and-176-usage-report-sharing`.
Do not add a backend, analytics SDK, persistent consent toggle, or automatic upload.

## Visual Gate

The change adds an About section and a disclosure sheet, so operator visual approval is required.
Prepare simulator captures in Korean and English at the final candidate SHA.
Do not mark the PR merge-ready before the operator approves those artifacts.

## Step 1: Prove The Export Contract Fails

Owned paths:

- `QuestKeeperTests/UsageReportExportTests.swift`
- `QuestKeeperTests/Fixtures/OnboardingExperimentFixture.swift`
- `QuestKeeperTests/Fixtures/RetentionBaselineFixture.swift`

Add focused tests that name these breaks:

- the export type is absent;
- optional retention incorrectly blocks an otherwise valid export;
- forbidden identifier or raw-content keys enter encoded JSON;
- invalid onboarding data produces a share item.

Run the focused tests before production code.
Record the expected compile failure caused by the missing production type.

## Step 2: Build The Pure Export Boundary

Owned paths:

- `QuestKeeperShared/UsageReportExport.swift`
- `QuestKeeperShared/OnboardingExperimentStore.swift`
- `QuestKeeperShared/RetentionBaselineStore.swift`

Add the smallest versioned payload and loader that satisfy the failing tests.
Read only existing aggregate report files.
Keep onboarding required and retention optional.
Encode ISO 8601 dates with sorted keys.

Run the focused unit tests.
Make an adversarial copy of the encoded fixture that contains a forbidden key and confirm the privacy assertion fails before trusting the passing result.

## Step 3: Prove The Disclosure Flow Fails

Owned paths:

- `QuestKeeperUITests/UsageReportSharingUITests.swift`
- `QuestKeeper/Debug/DebugUsageReportFixture.swift`
- `QuestKeeper/QuestKeeperApp.swift`

Add a deterministic debug-only fixture that supplies an aggregate report through the production loader boundary.
Add UI tests for the ready and unavailable states.
Run the focused UI test before adding the new About controls and record the missing-control failure.

## Step 4: Add The About And Share Surfaces

Owned paths:

- `QuestKeeper/Views/AboutSheet.swift`
- `QuestKeeper/Views/UsageReportShareSheet.swift`
- `QuestKeeper/Views/AppStrings.swift`
- `QuestKeeper/Localizable.xcstrings`

Add the `App Improvement` section and disclosure sheet.
Use `ShareLink` with a JSON `Transferable` item.
Give the About row, unavailable state, and share action stable accessibility identifiers.

Run the focused unit test, focused UI test, and `bash scripts/test-localization.sh`.

## Step 5: Align Repository Claims

Owned paths:

- `README.md`
- `docs/legal/privacy-policy.md`
- `docs/legal/terms-of-service.md`
- `fastlane/metadata/ko/description.txt`
- `fastlane/metadata/en-US/description.txt`
- `docs/store/app-store-listing.md`

Describe the user-directed aggregate report exception without claiming automatic analytics or anonymous transport.
Record the required App Store Connect Usage Data disclosure as linked analytics data for the developer email receipt channel.
Keep App Store Connect publication and the separate landing-site deployment outside this PR.
Record both as release prerequisites in the spec and PR.

Run the repository Markdown and store-copy checks that cover these files.
Inspect the rendered meaning because string and document gates cannot verify legal accuracy.

## Step 6: Verify And Review

Run:

```bash
swiftc -parse QuestKeeperShared/UsageReportExport.swift QuestKeeper/Views/UsageReportShareSheet.swift QuestKeeper/Views/AboutSheet.swift
bash scripts/test-localization.sh
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination "platform=iOS Simulator,id=${SIM_ID}" -parallel-testing-enabled NO -only-testing:QuestKeeperTests/UsageReportExportTests
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination "platform=iOS Simulator,id=${SIM_ID}" -parallel-testing-enabled NO -only-testing:QuestKeeperUITests/UsageReportSharingUITests
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination "platform=iOS Simulator,id=${SIM_ID}" -parallel-testing-enabled NO -only-testing:QuestKeeperTests
```

Run the repository's pre-commit checks through the normal commit hook.
Perform parallel read-only review passes because the final change set spans more than 15 files, then cross-check the findings inline.
Repair only verified findings within the approved contract.

## Step 7: Prepare Visual Evidence

Launch the deterministic fixture in Korean and English.
Capture the About section and the disclosure sheet.
Inspect default and accessibility Dynamic Type behavior.
Record the artifact paths and candidate SHA in the PR-loop state.

## Step 8: Deliver The PR

Use `semantic-commit` to separate the contract documentation from the product implementation when both concerns remain independently useful.
Push the branch and open a PR that closes AND-176.
Start the bounded public-repository review and CI loop.
Stop for operator visual approval or operator merge when all other readiness gates pass.
