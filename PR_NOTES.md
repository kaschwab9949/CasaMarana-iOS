# Casa Marana Stabilization Notes

Date run: 2026-03-01 (America/Phoenix)
Scope: stabilize current branch + merge readiness (no roadmap changes)

## What Was Stabilized
- Added root `.gitignore` for `.DS_Store`, `*.xcuserstate`, `**/xcuserdata/`, `**/xcdebugger/`.
- Removed tracked user-local scheme management file from `xcuserdata`.
- Preserved `Casa Marana` naming and test linkage alignment in project settings.
  - `TEST_HOST = $(BUILT_PRODUCTS_DIR)/Casa Marana.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Casa Marana`
  - `TEST_TARGET_NAME = Casa Marana`
- Preserved Release manual-signing model (no team/profile strategy changes).
- Hardened app config loading to plist/build-setting-backed values:
  - `CMBackendBaseURL`
  - `CMAPIKey`
  - Build settings source keys: `CM_BACKEND_BASE_URL`, `CM_API_KEY`
- Kept import-sensitive compile safeguards:
  - `import Combine` in `EventsFeedModel`, `VenueLocationManager`, `AppSession`, `MenuView`
  - `import CoreLocation` in `ContentTabsView`
- Expanded deterministic unit + UI tests.
- Added/maintained accessibility identifiers for deterministic UI traversal across rewards/auth/menu/settings/navigation/tab surfaces.

## Required Config Keys
- `CMBackendBaseURL` (string URL)
- `CMAPIKey` (string; may be empty in local debug)

These are now present in built app Info.plist via build-setting substitution.

## Manual Smoke Matrix (iPhone 17, iOS 26.2)
- Launch to Home: PASS (`testTabNavigationAndCoreSmokeFlow` ends on Home screen id `screen.home`)
- Tab switching Rewards/Events/Menu/Snake/Settings: PASS (`testTabNavigationAndCoreSmokeFlow` + `testOverflowTabsAndSettingsEraseFlow`)
- Rewards sign-in validation (phone + PIN constraints): PASS (`testRewardsSignInValidationShowsPhoneAndPINErrors`)
- Rewards refresh handling success/error surfacing: PASS (`testTabNavigationAndCoreSmokeFlow`, `assertRewardsRefreshOutcomeAppeared`)
- Menu search filtering: PASS (`testTabNavigationAndCoreSmokeFlow`, query `Margherita`)
- Settings erase-local-profile confirm flow: PASS (`testOverflowTabsAndSettingsEraseFlow`)
- Launch performance test: PASS (`testLaunchPerformance`)

## Validation Commands Run
- Debug simulator build:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project "Square Tier.xcodeproj" -scheme "Casa Marana" -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2'`
  - Result: `** BUILD SUCCEEDED **`
- Full tests:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -collect-test-diagnostics never -project "Square Tier.xcodeproj" -scheme "Casa Marana" -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2'`
  - Result: `** TEST SUCCEEDED **`
- Release archive (non-distributive packaging validation):
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild archive -project "Square Tier.xcodeproj" -scheme "Casa Marana" -configuration Release -destination 'generic/platform=iOS' -archivePath '/tmp/CasaMarana-Release-unsigned.xcarchive' CODE_SIGNING_ALLOWED=NO`
  - Result: `** ARCHIVE SUCCEEDED **`

## Release Signing Preservation Note
- Project Release settings remain manual-signing with existing profile fields intact.
- Manual archive path (without `CODE_SIGNING_ALLOWED=NO`) reaches signing with the configured identity/profile in this repo configuration.

## Known Non-Blocking Warning
- `warning: Metadata extraction skipped. No AppIntents.framework dependency found.`
