import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var repository: ActivityRepository
    @State private var stepsGoal = 10_000.0
    @State private var workoutGoal = 150.0
    @State private var activeEnergyGoal = ""
    @State private var displayName = "You"
    @State private var selectedDistanceUnit: DistanceUnit = .miles
    @State private var selectedAppTheme: AppTheme = .light
    @State private var visibleDashboardMetrics = Set(DashboardMetric.allCases)

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
                    Button("Reconnect Health") {
                        Task { await repository.requestHealthAccess() }
                    }
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

    private var healthStatusText: String {
        switch repository.authorizationState {
        case .notDetermined: "Not connected"
        case .unavailable: "Unavailable"
        case .authorized: "Connected"
        case .deniedOrLimited: "Limited or denied"
        }
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

        return "\(repository.liveActivityStatus.detail) StrideSlip refreshes it when your steps update."
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
