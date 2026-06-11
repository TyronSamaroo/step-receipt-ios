# App Store Connect Submission Notes

Use this file when creating the App Store Connect app, uploading the first build, and preparing the first TestFlight beta for Tiffany.

## App Record

| Field | Value |
| --- | --- |
| Platform | iOS |
| Name | StepReceipt |
| Bundle ID | `com.tyronsamaroo.stepreceipt` |
| SKU | `stepreceipt-ios-001` |
| Primary category | Health & Fitness |
| Version | `0.1.0` |
| Build | `2` |

## Beta App Review Notes

StepReceipt is a personal Apple Health activity dashboard. It requests read-only HealthKit access for steps, walking/running distance, active energy, flights climbed, and workouts. The app shows a Today timeline, activity history, workout detail views, insight receipts, goals, share cards, and an opt-in household competition board.

Raw HealthKit samples, hourly buckets, workout source identifiers, and workout details stay on the user's iPhone. CloudKit sync is limited to aggregate daily summaries, goals/preferences, and opt-in aggregate competition totals for a household invite code. The app does not write workouts or health samples in this version.

Suggested reviewer path:

1. Launch StepReceipt.
2. Grant Health permissions or choose Preview Sample Data if Health data is unavailable.
3. Review Today, Activity, Insights, Settings, and Competition tabs.
4. In Competition, generate a household code or join from a copied code to verify the aggregate-only leaderboard flow.

## TestFlight Beta Description

StepReceipt turns Apple Health movement data into a simple daily activity receipt: hourly steps, distance, active calories, workouts, goal progress, insights, and a lightweight household competition board.

This beta focuses on validating HealthKit permission handling, real step/workout reads, aggregate-only iCloud sync, and the household competition flow between Tyron and Tiffany.

## App Privacy Answers

Recommended App Store Connect privacy posture:

- Tracking: No.
- Third-party advertising: No.
- Data used for tracking: None.
- Health and Fitness data: Collected for app functionality.
- Identifiers: Not collected for tracking.
- Location: Not collected.
- Contact info: Not collected by the app.
- Diagnostics: Do not declare unless Apple/Xcode crash reporting or another integrated service is intentionally enabled and surfaced in App Store Connect.

Health and Fitness details:

- Data examples: steps, walking/running distance, active energy, flights climbed, workouts, workout duration, and aggregate competition totals.
- Purpose: app functionality.
- Linked to user: yes when stored in the user's private iCloud account or household competition board.
- Tracking: no.
- Shared with third parties: no, outside of Apple's HealthKit/iCloud infrastructure selected by the user.

CloudKit details:

- Private database stores aggregate daily summary records for the signed-in iCloud user.
- Public competition board stores only aggregate leaderboard rows keyed by a household invite code.
- Raw HealthKit samples, hourly buckets, individual workout details, workout source identifiers, and source names are not uploaded.

## Export Compliance

StepReceipt does not implement custom encryption. Build `2` declares `ITSAppUsesNonExemptEncryption = false` because the app does not implement non-exempt encryption and relies on Apple platform security, TLS, HealthKit, and CloudKit transport.

## TestFlight Groups

1. Create an internal testing group first if App Store Connect requires one.
2. Create external group `Family Beta`.
3. Add Tiffany by Apple ID email address.
4. Add the processed build to `Family Beta`. The first external build is submitted to beta review when it is added to the group.
5. After approval, send the invite and verify Tiffany can install, open onboarding, grant or deny Health permissions, set board name `Tiffany`, join from Tyron's copied household code, and see both aggregate rows after sync.

## Apple References

- [TestFlight](https://developer.apple.com/testflight/)
- [Invite external testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/)
- [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
- [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)
- [Health and Fitness apps](https://developer.apple.com/health-fitness/)
