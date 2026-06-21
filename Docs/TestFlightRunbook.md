# TestFlight Runbook

This is the handoff path for proving StepReceipt on Tyron's iPhone first, then installing it on Tiffany's iPhone through TestFlight. Keep this file current as signing, App Store Connect, and device proof move from pending to verified.

## Current Local State

| Item | State |
| --- | --- |
| App name | `StepReceipt` |
| Bundle ID | `com.tyronsamaroo.stepreceipt` |
| Version / build | `0.1.0` / `2` |
| Privacy manifest | `StepReceiptApp/PrivacyInfo.xcprivacy` declares `NSPrivacyAccessedAPICategoryUserDefaults` reason `CA92.1` |
| Health entitlement | Enabled in `StepReceiptApp/StepReceipt.entitlements` |
| CloudKit container | `iCloud.com.tyronsamaroo.stepreceipt` in entitlements |
| Development Team | Configured as `U63TLL4JY4` in `project.yml` |
| Device proof | Tyron's iPhone TT and Tiffany iPhone16 Pro have production bundle `0.1.0 (2)` installed and launched |
| GitHub push | Pending; do not push until repository visibility is confirmed |

Run the local readiness gate whenever signing, device, or repository state changes:

```bash
Tools/device-testflight-readiness.sh
```

It should pass when at least one development-ready iPhone is connected or paired. The Apple Developer team and local signing identities are already configured on this Mac.

## Temporary Personal-Team iPhone Proof Fallback

If the paid team becomes unavailable in Xcode, a free Xcode personal team can still run a same-day local HealthKit proof. That fallback cannot ship TestFlight and cannot sign the production iCloud/CloudKit entitlement set.

For a temporary local install only, connect Tyron's iPhone and run:

```bash
Tools/install-local-personal-iphone.sh
```

The script builds bundle id `com.tyronsamaroo.stepreceipt.local` with `StepReceiptApp/StepReceipt.LocalPersonal.entitlements` and `LOCAL_NO_CLOUDKIT`. That keeps raw HealthKit proof available while making CloudKit visibly disabled inside the app. Do not use this build for Tiffany, App Store Connect, or CloudKit validation.

## Apple Account And Signing

1. Open Xcode and confirm the paid `Tyron Samaroo` team appears under **Xcode > Settings > Accounts**.
2. Confirm Xcode still shows team ID `U63TLL4JY4`.
3. In the Apple Developer portal, create or confirm the App ID `com.tyronsamaroo.stepreceipt` with these capabilities:
   - HealthKit
   - iCloud with CloudKit
4. Create or confirm the CloudKit container `iCloud.com.tyronsamaroo.stepreceipt`.
5. In CloudKit Dashboard, confirm these record types exist in **development** and **production** for container `iCloud.com.tyronsamaroo.stepreceipt`:
   - `DailyActivitySummary` in the **private** database.
   - `HouseholdCompetitionBoard` in the **public** database (fields: `groupHash`, `schemaVersion`, `inviteCodeHint`, `entryNames`, `privacyBoundary`, `updatedAt`).
   - `CompetitionEntry` in the **public** database (fields: `groupHash`, `schemaVersion`, `competitorID`, `displayName`, `initials`, `accentHex`, `dayKey`, `steps`, `distanceMeters`, `activeEnergyKilocalories`, `workoutMinutes`, `updatedAt`).
   - Public database security roles: authenticated iCloud users can create, read, and write both public types. Boards are fetched by deterministic record ID from the hashed household invite code, so no public query index is required.
   - See `Docs/CloudKitCompetitionSchema.md` for the full field checklist.
6. If the team ID ever changes, copy the Apple Developer Team ID into `project.yml`:

   ```yaml
   DEVELOPMENT_TEAM: "<TEAM_ID>"
   ```

7. Regenerate the project and review the signing diff after any signing-setting change:

   ```bash
   xcodegen generate
   git diff -- project.yml StepReceipt.xcodeproj/project.pbxproj
   ```

8. Commit signing setup separately from feature work.

Do not invent a team ID. Use the value shown by Xcode or the Apple Developer portal.

## Physical iPhone Proof

Use Tyron's iPhone as the first proof device before TestFlight.

1. Connect the iPhone by USB or pair it wirelessly in Xcode.
2. Trust the Mac on the iPhone and enable Developer Mode if iOS prompts for it.
3. Select the physical iPhone as the run destination in Xcode.
4. Build and run `StepReceipt`.
   - CLI path: `Tools/install-production-iphone.sh`
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
7. In the Competition tab, set the board name to `Tyron`, create a household code, sync, then share or copy the code for Tiffany. Confirm the leaderboard still shows Tyron's aggregate row if CloudKit is offline.
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

Use [App Store Connect Submission Notes](AppStoreConnectSubmission.md) for beta review notes, TestFlight description, privacy answers, export-compliance posture, and the Family Beta tester flow.

| Field | Value |
| --- | --- |
| Platform | iOS |
| Name | `StepReceipt` |
| Bundle ID | `com.tyronsamaroo.stepreceipt` |
| SKU | `stepreceipt-ios-001` |
| Category | Health & Fitness |
| Version | `0.1.0` |

Build `1` was uploaded first and left with missing compliance. Build `2` declares `ITSAppUsesNonExemptEncryption = false` and is the active TestFlight candidate. If build `2` is replaced, increment `CURRENT_PROJECT_VERSION` in `project.yml`, regenerate `StepReceipt.xcodeproj`, and commit that build-number bump before archiving.

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

Current App Store Connect state as of 2026-06-11:

- Build `0.1.0 (2)` has been submitted for external TestFlight beta review and shows `Waiting for Review`.
- Tiffany was added as an individual external tester at her Apple ID email.
- App Store Connect showed `No Builds Available` for Tiffany until beta review approval, which is expected for the first external build.
- The direct Xcode install path is complete on both Tyron's iPhone TT and Tiffany iPhone16 Pro with bundle `com.tyronsamaroo.stepreceipt`, version `0.1.0`, build `2`.

1. In App Store Connect, open TestFlight for `StepReceipt`.
2. Prefer external group `Family Beta` for future testers when App Store Connect exposes the external group flow.
3. For the first wife beta, Tiffany is already attached directly to build `0.1.0 (2)` as an individual external tester.
4. After Apple's first beta review approval, confirm the invite was sent automatically or resend it from the tester row.
5. If moving to a group later, create `Family Beta`, add Tiffany, and attach the approved build to that group.
6. After approval, send or verify the TestFlight invite.
7. Verify on Tiffany's iPhone:
   - TestFlight install succeeds.
   - App opens to onboarding.
   - Health permission prompt appears.
   - Denied or partial Health access still leaves the app usable.
   - Competition board name is set to `Tiffany` before syncing.
   - Tiffany can use `Join from Clipboard` after copying Tyron's invite message.
   - The same household code shows both Tyron and Tiffany on the competition leaderboard after each phone syncs.
   - Raw samples, hourly buckets, workouts, source identifiers, and workout details are absent from public `CompetitionEntry` records.

Tiffany's phone does not need to be connected to this Mac for the TestFlight path.

## Acceptance Checklist

- [x] Apple Developer paid team confirmed.
- [x] `DEVELOPMENT_TEAM` set and committed.
- [ ] App ID `com.tyronsamaroo.stepreceipt` has HealthKit and CloudKit capabilities.
- [ ] CloudKit container `iCloud.com.tyronsamaroo.stepreceipt` exists for the selected team.
- [ ] CloudKit schema includes private `DailyActivitySummary` and public `HouseholdCompetitionBoard` + `CompetitionEntry`.
- [x] Tyron's iPhone TT runs production bundle `0.1.0 (2)` from Xcode.
- [x] Tiffany iPhone16 Pro runs production bundle `0.1.0 (2)` from Xcode.
- [ ] Household-code competition sync shows Tyron and Tiffany aggregate leaderboard rows.
- [x] Local validation suite passes before archive.
- [x] Release archive validates and uploads.
- [x] App Store Connect build `0.1.0 (2)` finishes processing.
- [x] App Privacy and beta notes are complete enough for beta review.
- [ ] App Store Connect beta review approves build `0.1.0 (2)`.
- [ ] `Family Beta` external group is created if needed beyond the direct individual tester path.
- [ ] Tiffany receives the TestFlight invite, installs, and reaches onboarding.

## Apple References

- [Running your app in Simulator or on a device](https://developer.apple.com/documentation/xcode/running-your-app-in-simulator-or-on-a-device)
- [TestFlight](https://developer.apple.com/testflight/)
- [Describing use of required reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
