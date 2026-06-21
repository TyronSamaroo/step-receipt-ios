import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var repository: ActivityRepository
    @State private var stepsGoal = 10_000.0
    @State private var workoutGoal = 150.0
    @State private var activeEnergyGoal = ""
    @State private var displayName = "You"
    @State private var selectedDistanceUnit: DistanceUnit = .miles
    @State private var selectedAppTheme: AppTheme = .light
    @State private var visibleDashboardMetrics = Set(DashboardMetric.allCases)
    @State private var copiedDiagnostics = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Display name", text: $displayName)
                        .textInputAutocapitalization(.words)

                    Picker("Distance", selection: $selectedDistanceUnit) {
                        ForEach(DistanceUnit.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }

                    Button("Save Profile") {
                        repository.updatePreferences(
                            displayName: displayName,
                            distanceUnit: selectedDistanceUnit
                        )
                    }
                }

                Section("Appearance") {
                    Picker("Theme", selection: $selectedAppTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedAppTheme) { _, newTheme in
                        repository.updatePreferences(appTheme: newTheme)
                    }
                }

                Section("Today Metrics") {
                    ForEach(DashboardMetric.allCases) { metric in
                        Toggle(metric.displayName, isOn: Binding(
                            get: { visibleDashboardMetrics.contains(metric) },
                            set: { isVisible in
                                if isVisible {
                                    visibleDashboardMetrics.insert(metric)
                                } else {
                                    visibleDashboardMetrics.remove(metric)
                                }
                                repository.updatePreferences(
                                    visibleDashboardMetrics: DashboardMetric.allCases.filter { visibleDashboardMetrics.contains($0) }
                                )
                            }
                        ))
                    }
                }

                Section("Goals") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Daily steps", systemImage: StepReceiptSymbol.stepPrints)
                            Spacer()
                            Text(Int(stepsGoal).formatted())
                                .fontWeight(.semibold)
                        }
                        Slider(value: $stepsGoal, in: 2_000...25_000, step: 500)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Weekly workout", systemImage: StepReceiptSymbol.workout)
                            Spacer()
                            Text("\(Int(workoutGoal)) min")
                                .fontWeight(.semibold)
                        }
                        Slider(value: $workoutGoal, in: 0...420, step: 15)
                    }

                    TextField("Active calorie goal optional", text: $activeEnergyGoal)
                        .keyboardType(.numberPad)

                    Button("Save Goals") {
                        repository.updateGoals(
                            steps: Int(stepsGoal),
                            workoutMinutes: Int(workoutGoal),
                            activeEnergy: Int(activeEnergyGoal)
                        )
                    }
                }

                Section("Health") {
                    statusRow("Apple Health", healthStatusText, StepReceiptSymbol.healthCard)
                    statusRow("Data Refresh", healthRefreshStatusText, healthRefreshStatusIcon)
                    if let lastUpdated = healthLastUpdatedText {
                        statusRow("Last Updated", lastUpdated, "clock")
                    }
                    statusRow("Background Updates", backgroundDeliveryStatusText, backgroundDeliveryStatusIcon)
                    if let issue = repository.healthRefreshStatus.issue {
                        Text(issue)
                            .font(.footnote)
                            .foregroundStyle(Color.stepWarning)
                    }
                    if let backgroundIssue = backgroundDeliveryIssueText {
                        Text(backgroundIssue)
                            .font(.footnote)
                            .foregroundStyle(Color.stepWarning)
                    }

                    Button {
                        Task { await repository.refresh() }
                    } label: {
                        Label(repository.isLoading ? "Refreshing Apple Health" : "Refresh Apple Health", systemImage: StepReceiptSymbol.refresh)
                    }
                    .disabled(repository.isLoading || repository.authorizationState == .unavailable)

                    Button("Reconnect Health") {
                        Task { await repository.requestHealthAccess() }
                    }

                    Button {
                        Task { await repository.repairHealthSync() }
                    } label: {
                        Label(
                            repository.isRepairingHealthSync ? "Repairing Health Sync" : "Repair Health Sync",
                            systemImage: "wrench.and.screwdriver.fill"
                        )
                    }
                    .disabled(repository.isRepairingHealthSync || repository.authorizationState == .unavailable)
                    .accessibilityIdentifier("repair-health-sync-button")
                }

                Section("iCloud") {
                    statusRow("Private Summary Sync", cloudStatusText, StepReceiptSymbol.cloud)
                }

                Section("Live Activity") {
                    Toggle(isOn: Binding(
                        get: { repository.preferences.dailyStepGoalLiveActivityEnabled },
                        set: { isEnabled in
                            Task { await repository.setDailyStepGoalLiveActivityEnabled(isEnabled) }
                        }
                    )) {
                        Label("Lock Screen steps", systemImage: "iphone.radiowaves.left.and.right")
                    }
                    .tint(Color.stepAccent)

                    statusRow("Status", repository.liveActivityStatus.title, "circle.fill")

                    Text(liveActivityDetail)
                        .font(.footnote)
                        .foregroundStyle(Color.stepMuted)
                }

                Section("Diagnostics") {
                    statusRow("App", appVersionAndBuildText, "app")
                    statusRow("Apple Health", healthStatusText, StepReceiptSymbol.healthCard)
                    statusRow("Last Health Refresh", healthRefreshDiagnosticsText, healthRefreshStatusIcon)
                    statusRow("Background Updates", backgroundDeliveryDiagnosticsText, backgroundDeliveryStatusIcon)
                    statusRow("iCloud", cloudStatusText, StepReceiptSymbol.cloud)
                    statusRow("Household Board", competeBoardStatusText, StepReceiptSymbol.competitionTab)
                    statusRow("Household Members", "\(repository.householdMembers.count)", "person.2")
                    statusRow("Compete Sync", competeSyncStatusText, "arrow.triangle.2.circlepath")
                    statusRow("Live Activity", repository.liveActivityStatus.title, "iphone.radiowaves.left.and.right")

                    Button {
                        UIPasteboard.general.string = diagnosticsSummary.text
                        copiedDiagnostics = true
                    } label: {
                        Label(copiedDiagnostics ? "Diagnostics copied" : "Copy Diagnostics", systemImage: "doc.on.doc")
                    }
                    .accessibilityIdentifier("copy-diagnostics-button")

                    Text("Diagnostics only copies app and sync status. It does not include raw Health data, activity totals, workouts, routes, or household codes.")
                        .font(.footnote)
                        .foregroundStyle(Color.stepMuted)
                }

                Section("Privacy") {
                    Text("StepReceipt reads HealthKit data on-device and syncs only aggregate daily summary records, preferences, goals, and opt-in household competition totals. Raw samples, hourly buckets, workout details, and source identifiers are not uploaded.")
                        .font(.footnote)
                        .foregroundStyle(Color.stepMuted)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                stepsGoal = Double(repository.goals.stepsPerDay)
                workoutGoal = Double(repository.goals.workoutMinutesPerWeek)
                activeEnergyGoal = repository.goals.activeEnergyKilocaloriesPerDay.map(String.init) ?? ""
                displayName = repository.preferences.displayName
                selectedDistanceUnit = repository.preferences.distanceUnit
                selectedAppTheme = repository.preferences.appTheme
                visibleDashboardMetrics = Set(repository.preferences.visibleDashboardMetrics)
            }
        }
    }

    private var diagnosticsSummary: AppDiagnosticsSummary {
        let competeDiagnostics = repository.competitionSyncDiagnostics
        return AppDiagnosticsSummary(
            appVersion: AppDiagnosticsSummary.appVersion(),
            appBuild: AppDiagnosticsSummary.appBuild(),
            appleHealthStatus: healthStatusText,
            healthRefreshStatus: healthRefreshStatusText,
            healthLastRefresh: healthLastUpdatedText,
            healthBackgroundUpdates: backgroundDeliveryDiagnosticsText,
            iCloudStatus: cloudStatusText,
            liveActivityStatus: repository.liveActivityStatus.title,
            competeBoardStatus: competeBoardStatusText,
            competeMemberCount: competeDiagnostics.memberCount,
            competeSyncStatus: competeDiagnostics.lastSyncState
        )
    }

    private var competeBoardStatusText: String {
        switch repository.competeBoardPhase {
        case .setup: "Not joined"
        case .waitingForPartner: "Waiting for partner"
        case .active: "Active"
        case .needsAttention: "Needs attention"
        }
    }

    private var competeSyncStatusText: String {
        repository.competitionSyncDiagnostics.lastSyncDetail
    }

    private var appVersionAndBuildText: String {
        "\(AppDiagnosticsSummary.appVersion()) (\(AppDiagnosticsSummary.appBuild()))"
    }

    private var healthStatusText: String {
        switch repository.authorizationState {
        case .notDetermined: "Not connected"
        case .unavailable: "Unavailable"
        case .authorized: "Connected"
        case .deniedOrLimited: "Limited or denied"
        }
    }

    private var healthRefreshStatusText: String {
        if repository.isLoading {
            return "Refreshing"
        }

        return switch repository.healthRefreshStatus.outcome {
        case .idle: "Ready"
        case .refreshing: "Refreshing"
        case .current: "Current"
        case .partial: "Partial"
        case .cached: "Saved data"
        case .failed: "Needs retry"
        }
    }

    private var healthRefreshStatusIcon: String {
        if repository.isLoading {
            return "arrow.triangle.2.circlepath"
        }

        return switch repository.healthRefreshStatus.outcome {
        case .idle:
            StepReceiptSymbol.refresh
        case .refreshing:
            "arrow.triangle.2.circlepath"
        case .current:
            "checkmark.circle.fill"
        case .partial:
            "exclamationmark.triangle.fill"
        case .cached:
            "externaldrive.fill"
        case .failed:
            "xmark.octagon.fill"
        }
    }

    private var backgroundDeliveryStatusText: String {
        switch repository.healthBackgroundDeliveryState {
        case .notConfigured:
            "Not configured"
        case .configuring:
            "Configuring"
        case .configured:
            "Ready"
        case .unavailable:
            "Needs repair"
        }
    }

    private var backgroundDeliveryStatusIcon: String {
        switch repository.healthBackgroundDeliveryState {
        case .notConfigured:
            "antenna.radiowaves.left.and.right.slash"
        case .configuring:
            "arrow.triangle.2.circlepath"
        case .configured:
            "antenna.radiowaves.left.and.right"
        case .unavailable:
            "exclamationmark.triangle.fill"
        }
    }

    private var backgroundDeliveryDiagnosticsText: String {
        switch repository.healthBackgroundDeliveryState {
        case .notConfigured:
            "Not configured"
        case .configuring:
            "Configuring"
        case .configured(let date):
            "Ready · \(formattedStatusDate(date))"
        case .unavailable:
            "Needs repair"
        }
    }

    private var backgroundDeliveryIssueText: String? {
        if case .unavailable(let issue) = repository.healthBackgroundDeliveryState {
            return issue
        }

        return nil
    }

    private var healthLastUpdatedText: String? {
        let status = repository.healthRefreshStatus
        guard let date = status.lastSuccessfulAt ?? status.lastCompletedAt else {
            return nil
        }

        if Calendar.current.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }

        return date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    private func formattedStatusDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }

        return date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    private var healthRefreshDiagnosticsText: String {
        if let healthLastUpdatedText {
            return "\(healthRefreshStatusText) · \(healthLastUpdatedText)"
        }

        return healthRefreshStatusText
    }

    private var cloudStatusText: String {
        switch repository.cloudSyncState {
        case .unknown: "Checking"
        case .available: "Available"
        case .unavailable(let reason): reason
        }
    }

    private var canStartOrUpdateLiveActivity: Bool {
        guard let summary = repository.todaySummary else { return false }
        return Calendar.current.isDateInToday(summary.dateStart)
    }

    private var liveActivityDetail: String {
        guard repository.preferences.dailyStepGoalLiveActivityEnabled else {
            return "Turn this on to keep today's step goal visible on the Lock Screen and Dynamic Island."
        }

        guard canStartOrUpdateLiveActivity else {
            return "StrideSlip will start it after today's step summary loads."
        }

        return "\(repository.liveActivityStatus.detail) While the app is open, StrideSlip refreshes about once a minute. On the Lock Screen, iOS decides when HealthKit background step updates wake the app."
    }

    private func statusRow(_ title: String, _ value: String, _ icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Text(value)
                .foregroundStyle(Color.stepMuted)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }
}
