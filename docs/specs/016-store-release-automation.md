# Store Release Automation

## Goal

Generate reproducible Korean App Store screenshots and the current version's “What’s New” metadata without uploading or changing an App Store Connect record.

## Screenshot pipeline

Fastlane Snapshot runs only `StoreScreenshotUITests` in a Debug build on the highest-resolution iPhone simulator configured in `fastlane/Snapfile`.
The app uses an in-memory SwiftData store and a DEBUG-only launch fixture, so captures do not read or mutate personal quest data.
Six product states are captured into `fastlane/screenshots/generated/ko` while the previously downloaded store screenshots remain untouched.
`scripts/process-store-screenshots.sh` converts the raw Simulator PNG files to 8-bit RGB without alpha.
`scripts/validate-store-screenshots.sh` then requires all six named PNG files, an Apple-supported 6.9-inch portrait size, 8-bit channels, and no alpha channel.

## Release-note pipeline

`scripts/prepare-release-notes.sh` reads the version from the Xcode project.
When `docs/releases/<version>/ko.txt` is missing, it creates a Korean draft from user-facing conventional commits since the latest version tag.
An existing versioned file is treated as curated copy and is never regenerated.
The validated file is copied to `fastlane/metadata/ko/release_notes.txt`, which is the App Store Connect “What’s New in This Version” field.

## Commands

```bash
bundle exec fastlane ios release_notes
bundle exec fastlane ios screenshots
bundle exec fastlane ios store_assets
```

`store_assets` prepares both local surfaces and performs no upload.
The existing `release` lane remains the only lane that builds and uploads a release.

## Export compliance

The app target sets `ITSAppUsesNonExemptEncryption` to `NO` in Debug and Release generated Info.plists.
This declaration is valid only while the app and its linked dependencies use no encryption or only encryption that is exempt from export documentation requirements.
