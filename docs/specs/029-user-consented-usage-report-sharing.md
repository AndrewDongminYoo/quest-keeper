# User-Consented Usage Report Sharing

Tracked as Linear issue AND-176.

## Problem

TODO Slayer assigns eligible installations to the `control` or `guided` onboarding variant.
The app also records retention events and generates aggregate reports.
These reports stay in the App Group container, so the developer cannot observe real-user experiment results.

App Store Connect reports standard installation and app-usage metrics.
It does not receive the app-defined experiment assignment or funnel report.

## Decision

Add a one-time `Share Usage Report` action to the existing About sheet.
The action opens a disclosure sheet before the system share sheet becomes available.
The user must start each export.

The first version does not add a persistent consent toggle.
A toggle without a transmission service would be misleading, while an automatic service would add backend, retention, and broader App Privacy work that the current audience does not justify.

Do not describe the report as anonymous.
The report excludes direct identifiers, but the share destination can expose the sender's account or other transport metadata.

## Product Flow

The About sheet adds an `App Improvement` section after the legal links and before the tip section.
The section contains one `Share Usage Report` row.

When the user selects the row:

1. Open a disclosure sheet.
2. Explain which aggregate data the report contains.
3. Explain which personal and task data the report excludes.
4. Show an unavailable state if no valid onboarding experiment report exists.
5. Show `Continue to Share` only when a valid report exists.
6. Let the user choose the destination through the system share sheet.

Cancellation does not modify local measurement data or app state.

## Export Contract

Add `UsageReportExport` as an explicit, versioned JSON envelope.
The payload contains:

- export schema version;
- app marketing version;
- app build number;
- an export-specific allowlisted projection of `OnboardingExperimentReport`;
- an export-specific allowlisted projection of `RetentionReport` when it is available.

The aggregate reports include their reporting periods, reporting time zone, and data-quality summary.
The retention projection includes scenario-validation counts but omits the underlying missing and forbidden deduplication keys.
Adding a field to either local report type must not add that field to the export automatically.

The onboarding experiment report is required because it carries the assigned-variant cohort and the experiment funnel.
The retention baseline is optional so a valid experiment report remains shareable when the separate retention file is absent or invalid.

Encode dates as ISO 8601 values.
Sort JSON keys so exported files are stable enough to inspect and aggregate.
Use the filename `todo-slayer-usage-report-v1.json`.

The export must not contain:

- installation UUIDs;
- quest UUIDs;
- quest titles or descriptions;
- notification content;
- individual event rows;
- account, contact, advertising, device, location, or IP identifiers.

Load only the existing aggregate report files.
Do not query SwiftData or regenerate measurement data when the user opens the disclosure sheet.

## Failure Behavior

An absent, corrupt, or unsupported onboarding report produces the same unavailable state.
The app does not create a replacement report during the share flow.

An absent, corrupt, or unsupported retention report does not block export.
The exported envelope omits that optional report.

If JSON encoding fails, do not open the system share sheet.
Show a localized failure message and keep the About sheet usable.

## Privacy And Release Contract

The app has no automatic analytics, backend, account, or background upload after this change.
The only new transmission path is the system share sheet after explicit user action.
The user chooses the receiving app and destination.

Update the repository privacy policy, terms, README, and both App Store description locales so they do not claim that all data always stays on the device.
The policy must explain the report contents, the explicit action, the destination choice, and the developer's retention practice when the developer receives a report.

Before a release contains this feature:

- Update App Store Connect App Privacy to disclose Product Interaction and Other Usage Data used for Analytics, linked to the user, and not used for tracking.
- Copy both legal documents to the Korean and English landing-site sources.
- Publish the landing-site copies with an effective date that matches publication.

Apple's current optional-disclosure criteria require the user's name or account name to appear with the submitted data.
This flow intentionally does not collect or display that identity, so the release process must not rely on the optional-disclosure exception.
The conservative linked-data declaration accounts for reports that arrive through the developer email address alongside sender account information.
See [App privacy details on the App Store](https://developer.apple.com/app-store/app-privacy-details/).

Those publication actions are outside this repository PR.

## Localization And Accessibility

Every new user-facing string uses `AppStrings` and has Korean and English catalog values.
The About row and share action have stable accessibility identifiers.
The disclosure uses headings and body text that VoiceOver reads in content order.

The new sheet must remain readable at the default Dynamic Type size and at an accessibility size.
The operator must approve the rendered result before merge readiness.

## Acceptance Criteria

1. A valid onboarding experiment report produces a versioned JSON export with app version metadata.
2. A missing retention report produces a valid export without a retention section.
3. Missing, corrupt, or unsupported onboarding data produces an unavailable state and no share item.
4. A recursive inspection of the encoded JSON finds no forbidden identifier or raw-content keys.
5. The About sheet explains the report before a share action is available.
6. The system share sheet opens only from an explicit user action.
7. Korean and English strings pass the localization contract.
8. Repository privacy, terms, README, and App Store descriptions match the new user-directed export behavior.
9. Relevant unit and UI tests pass.
10. The operator approves simulator evidence for the new About and disclosure surfaces.

## Non-Goals

- Automatic or scheduled telemetry.
- A developer-operated endpoint.
- A third-party analytics SDK.
- A persistent consent toggle.
- App Tracking Transparency integration.
- Person-level analysis or cross-device identity.
- Automatic experiment winner selection.
- App Store Connect publication.
- Landing-site repository changes or deployment.

## Precedent

Oracle found a QuestKeeper precedent that paired privacy, terms, store, and landing claims must change together when the product's external communication changes.
The source is `wiki/sources/claude--projects---users-dongminyu-development-01-personal-quest-keeper--memory--paired-documents-drift-together.md` at source commit `c1681868ac634e4b2414874716bb75a7864113c4`.
Current-source freshness is unverified.
This precedent makes disclosure consistency part of the acceptance contract.

`[no precedent found]` for the export mechanism, payload fields, consent UI, developer receipt method, or retention implementation.
