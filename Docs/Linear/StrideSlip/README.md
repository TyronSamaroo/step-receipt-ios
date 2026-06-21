# StrideSlip Linear Import

This folder keeps StrideSlip tracking separate from Tyron's other projects.

Use this Linear scope:

- Workspace: `tyronsamaroo`
- Team: `TYR`
- Project: `StrideSlip iOS`
- Main isolation label: `project-strideslip-ios`

Files:

- `StrideSlipFeatureRegistry.linear.csv`: shipped capability registry. Import as `Done` issues if you want Linear to show what has already landed.
- `StrideSlipValidationBacklog.linear.csv`: active validation and backlog. Import as `Todo` issues first if you want a smaller working board.

Recommended Linear views after import:

- `StrideSlip - Needs Validation`: label `project-strideslip-ios` + label `validation` + not completed.
- `StrideSlip - HealthKit + Live Activity`: label `project-strideslip-ios` + labels `healthkit` or `activitykit`.
- `StrideSlip - Compete`: label `project-strideslip-ios` + label `compete`.
- `StrideSlip - Insights`: label `project-strideslip-ios` + label `insights`.
- `StrideSlip - Release`: label `project-strideslip-ios` + labels `release` or `testflight`.

Safe import path:

```bash
cd /Users/tyronsamaroo/CodeProjects/step-receipt-ios
ruby Tools/import-strideslip-linear.rb --validation-only
```

That command is a dry-run. To actually create Linear records, create a Linear personal API key locally and run:

```bash
export LINEAR_API_KEY='paste-token-here'
ruby Tools/import-strideslip-linear.rb --validation-only --apply
```

Do not commit or paste the API key into chat. The importer creates or reuses the `StrideSlip iOS` project, creates missing labels, skips existing matching titles in the project, and writes all issues to team `TYR`.
