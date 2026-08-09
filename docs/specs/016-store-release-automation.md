# Store Release Automation

## Goal

Generate reproducible App Store screenshots and the current version's “What’s New” metadata for every listing locale, without uploading or changing an App Store Connect record.

## Screenshot pipeline

Fastlane Snapshot runs only `StoreScreenshotUITests` in a Debug build on the highest-resolution iPhone simulator configured in `fastlane/Snapfile`, once per locale in that file's `languages`.
The app uses an in-memory SwiftData store and DEBUG-only launch fixtures, so captures do not read or mutate personal quest data.
The test pins no locale of its own — Snapshot's injected `-AppleLanguages` decides it — and identifies screens by `accessibilityIdentifier`, so the same test runs unchanged under every locale.
Eight product states are captured into `fastlane/screenshots/generated/<locale>` while the previously downloaded store screenshots remain untouched: `01-dungeon`, `02-battle`, `03-hero-appearance`, `04-focus-plan`, `05-focus-selection`, `06-daily-grave`, `07-quest-editor`, `08-empty-dungeon`.
`scripts/process-store-screenshots.sh` converts the raw Simulator PNG files to 8-bit RGB without alpha.
`scripts/validate-store-screenshots.sh` then requires all eight named PNG files per locale, an Apple-supported 6.9-inch portrait size, 8-bit channels, and no alpha channel.
Both scripts take the locale list as trailing arguments and default to `ko en-US`.

Monster sprites are chosen from each fixture quest's per-launch `UUID`, so re-running the lane redraws them and every PNG differs byte-for-byte from the committed one. That is expected; discard the rerun unless it was for a real content change.

## Release-note pipeline

`scripts/prepare-release-notes.sh` reads the version from the Xcode project, then discovers the listing locales from the `fastlane/metadata/*/` directories that contain a `name.txt` — the same set `deliver` treats as listings.
For each one it requires `docs/releases/<version>/<locale>.txt` to already exist and be non-empty; release notes are curated copy, so the script never drafts or regenerates them.
**Every listing locale needs its own source file.** A missing one fails the lane rather than being skipped, so adding a locale to `fastlane/metadata/` means adding its release notes for the current version too.
Each validated file is copied to `fastlane/metadata/<locale>/release_notes.txt`, which is the App Store Connect “What’s New in This Version” field.

## Commands

```bash
bundle exec fastlane ios release_notes
bundle exec fastlane ios screenshots
bundle exec fastlane ios store_assets
```

`store_assets` prepares both local surfaces and performs no upload.
The existing `release` lane remains the only lane that builds and uploads a release.

Snapshot writes derived data to its own default location. On a machine whose root volume is tight, redirect it for that run instead of pinning a path in `Snapfile` — the path is machine-specific and the file is shared:

```bash
SNAPSHOT_DERIVED_DATA_PATH=/path/with/room bundle exec fastlane ios screenshots
```

It authenticates with an App Store Connect API key read from the environment, because the binary upload runs through `altool`, which rejects a plain Apple ID password and the Spaceship session that the metadata upload uses.
Export these before running it; the private key must stay outside the repository.

```bash
export APP_STORE_CONNECT_API_KEY_KEY_ID=<key id>
export APP_STORE_CONNECT_API_KEY_ISSUER_ID=<issuer id>
export APP_STORE_CONNECT_API_KEY_KEY_FILEPATH=~/.private_keys/AuthKey_<key id>.p8
```

## Export compliance

The app target sets `ITSAppUsesNonExemptEncryption` to `NO` in Debug and Release generated Info.plists.
This declaration is valid only while the app and its linked dependencies use no encryption or only encryption that is exempt from export documentation requirements.
