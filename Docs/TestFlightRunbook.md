# TestFlight Runbook

This is the handoff path for proving StepReceipt on Tyron's iPhone first, then installing it on Tiffany's iPhone through TestFlight. Keep this file current as signing, App Store Connect, and device proof move from pending to verified.

## Current Local State

| Item | State |
| --- | --- |
| App name | `StepReceipt` |
| Bundle ID | `com.tyronsamaroo.stepreceipt` |
| Version / build | `0.1.0` / `1` |
| Privacy manifest | `StepReceiptApp/PrivacyInfo.xcprivacy` declares `NSPrivacyAccessedAPICategoryUserDefaults` reason `CA92.1` |
| Health entitlement | Enabled in `StepReceiptApp/StepReceipt.entitlements` |
| CloudKit container | `iCloud.com.tyronsamaroo.stepreceipt` in entitlements |
| Development Team | Pending; `DEVELOPMENT_TEAM` is intentionally blank until the real Apple team ID is known |
| Device proof | Pending; no iPhone proof is complete until the app runs on a trusted physical iPhone |
| GitHub push | Pending; do not push until repository visibility is confirmed |

Run the local readiness gate whenever signing, device, or repository state changes:

```bash
Tools/device-testflight-readiness.sh
```

It should fail until `DEVELOPMENT_TEAM` is set, a valid signing identity exists, and Tyron's iPhone is connected or paired.

## Apple Account And Signing

1. Open Xcode and sign in under **Xcode > Settings > Accounts**.
2. Confirm whether the account has a paid Apple Developer Program team. TestFlight requires App Store Connect access from an enrolled developer account.
3. In the Apple Developer portal, create or confirm the App ID `com.tyronsamaroo.stepreceipt` with these capabilities:
   - HealthKit
   - iCloud with CloudKit
4. Create or confirm the CloudKit container `iCloud.com.tyronsamaroo.stepreceipt`.
5. In CloudKit Dashboard, confirm the app can create these record types in the development environment:
   - `DailyActivitySummary` in the private database.
   - `CompetitionBoard` in the public database. Each board is fetched by deterministic record ID from the hashed household code, so no public query index is required for the wife beta.
6. Copy the Apple Developer Team ID into `project.yml`:

   ```yaml
   DEVELOPMENT_TEAM: "<TEAM_ID>"
   ```

7. Regenerate the project and review the signing diff:

   ```bash
   xcodegen generate
   git diff -- project.yml StepReceipt.xcodeproj/project.pbxproj
   ```

8. Commit the team setup separately from feature work.

Do not invent a team ID. Leave `DEVELOPMENT_TEAM` blank until Xcode or the Apple Developer portal shows the real value.

## Physical iPhone Proof

Use Tyron's iPhone as the first proof device before TestFlight.

1. Connect the iPhone by USB or pair it wirelessly in Xcode.
2. Trust the Mac on the iPhone and enable Developer Mode if iOS prompts for it.
3. Select the physical iPhone as the run destination in Xcode.
4. Build and run `StepReceipt`.
5. Grant Health permissions for:
   - Steps
   - Walking/running distance
   - Active energy
   - Flights climbed
   - Workouts
6. Verify these app surfaces with real Health data:
   - Onboarding permission state
   - Today hourly timeline
   - Activity history and filters
   - Workout detail and share sheet
   - Insight receipt
   - Settings goals/customization
   - Competition tab with local check-ins and household-code sync controls
   - CloudKit status when iCloud is available, disabled, and offline
7. Create a household code on Tyron's iPhone, sync, and confirm the leaderboard still shows Tyron's aggregate row if CloudKit is offline.
8. Repeat with partial permissions denied so the app still shows useful available data.

## Local Validation Before Archive

Run this suite before creating an App Store archive:

```bash
Tools/device-testflight-readiness.sh
xcodegen generate
plutil -lint StepReceiptApp/Info.plist StepReceiptApp/StepReceipt.entitlements StepReceiptApp/PrivacyInfo.xcprivacy
swift run StepReceiptCoreCheck
swift test --enable-swift-testing
xcodebuild -project StepReceipt.xcodeproj -scheme StepReceipt -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' test
xcodebuild -project StepReceipt.xcodeproj -scheme StepReceipt -configuration Release -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO
```

If the installed simulator differs, replace `iPhone 17,OS=26.5` with an available iOS 17+ simulator destination from:

```bash
xcodebuild -project StepReceipt.xcodeproj -scheme StepReceipt -showdestinations
```

## App Store Connect Setup

Create the App Store Connect app after the paid developer team and bundle ID are ready.

| Field | Value |
| --- | --- |
| Platform | iOS |
| Name | `StepReceipt` |
| Bundle ID | `com.tyronsamaroo.stepreceipt` |
| SKU | `stepreceipt-ios-001` |
| Category | Health & Fitness |
| Version | `0.1.0` |

Before upload, confirm App Store Connect has not already processed build `1` for version `0.1.0`. If build `1` is already used, increment `CURRENT_PROJECT_VERSION` in `project.yml`, regenerate `StepReceipt.xcodeproj`, and commit that build-number bump before archiving.

Use conservative privacy answers:

- Purpose: app functionality.
- Tracking: no tracking.
- Health data: StepReceipt reads HealthKit with consent.
- Cloud sync: aggregate daily summaries, goals, preferences, and opt-in household competition totals.
- Raw HealthKit samples, hourly buckets, workout source IDs, and individual workout details are not uploaded.

## Archive And Upload

1. In Xcode, select **Any iOS Device** or the physical iPhone destination.
2. Choose **Product > Archive** using a Release configuration.
3. In Organizer, validate the archive.
4. Upload to App Store Connect.
5. Wait for build processing to finish.
6. Add beta notes that describe the HealthKit permission flow, on-device raw sample privacy, and aggregate-only CloudKit sync.

After archive, verify the uploaded build still contains the manifest and entitlements from the final signed product:

```bash
plutil -p <archive-path>/Products/Applications/StepReceipt.app/PrivacyInfo.xcprivacy
codesign -d --entitlements :- <archive-path>/Products/Applications/StepReceipt.app
```

## Wife TestFlight Flow

1. In App Store Connect, open TestFlight for `StepReceipt`.
2. Create an external tester group named `Family Beta`.
3. Add Tiffany by her Apple ID email address.
4. Select the processed build and submit it for Apple's first external beta review.
5. After approval, send the TestFlight invite.
6. Verify on Tiffany's iPhone:
   - TestFlight install succeeds.
   - App opens to onboarding.
   - Health permission prompt appears.
   - Denied or partial Health access still leaves the app usable.
   - The same household code shows both Tyron and Tiffany on the competition leaderboard after each phone syncs.
   - Raw samples, hourly buckets, workouts, source identifiers, and workout details are absent from `CompetitionBoard.entriesJSON`.

Tiffany's phone does not need to be connected to this Mac for the TestFlight path.

## Acceptance Checklist

- [ ] Apple Developer paid team confirmed.
- [ ] `DEVELOPMENT_TEAM` set and committed.
- [ ] App ID `com.tyronsamaroo.stepreceipt` has HealthKit and CloudKit capabilities.
- [ ] CloudKit container `iCloud.com.tyronsamaroo.stepreceipt` exists for the selected team.
- [ ] CloudKit development schema includes private `DailyActivitySummary` and public `CompetitionBoard`.
- [ ] Tyron's iPhone runs the app from Xcode with real Health data.
- [ ] Household-code competition sync shows Tyron and Tiffany aggregate leaderboard rows.
- [ ] Local validation suite passes before archive.
- [ ] Release archive validates and uploads.
- [ ] App Store Connect build finishes processing.
- [ ] App Privacy and beta notes are complete.
- [ ] `Family Beta` external group is created.
- [ ] Tiffany receives the TestFlight invite, installs, and reaches onboarding.

## Apple References

- [Running your app in Simulator or on a device](https://developer.apple.com/documentation/xcode/running-your-app-in-simulator-or-on-a-device)
- [TestFlight](https://developer.apple.com/testflight/)
- [Describing use of required reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
