import SwiftUI

struct ActivityHistoryView: View {
    @EnvironmentObject private var repository: ActivityRepository
    @State private var selectedMode: ActivityHistoryMode = .days
    @State private var selectedKind: ActivityKind?
    @State private var selectedDayFilter: DailySummaryFilter = .all
    @State private var selectedDaySort: DailySummarySort = .newest

    private var filteredWorkouts: [WorkoutActivity] {
        repository.filteredWorkouts(kind: selectedKind)
    }

    private var daySummaries: [DailyActivitySummary] {
        repository.filteredDailySummaries(filter: selectedDayFilter, sort: selectedDaySort)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("History", selection: $selectedMode) {
                        ForEach(ActivityHistoryMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if selectedMode == .days {
                        daysList
                    } else {
                        workoutsList
                    }
                }
                .padding(16)
            }
            .safeAreaPadding(.bottom, 84)
            .background(Color.stepBackground)
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var daysList: some View {
        VStack(alignment: .leading, spacing: 16) {
            dayControls

            if daySummaries.isEmpty {
                ContentUnavailableView(
                    "No day history",
                    systemImage: StepReceiptSymbol.activityTab,
                    description: Text("Try a different day filter or connect Apple Health.")
                )
                .padding(.top, 80)
            } else {
                ForEach(daySummaries) { summary in
                    NavigationLink {
                        DaySummaryDetailView(summary: summary)
                    } label: {
                        DaySummaryRow(summary: summary, distanceUnit: repository.preferences.distanceUnit)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded {
                        Task { await repository.selectDate(summary.dateStart) }
                    })
                }
            }
        }
    }

    private var dayControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DailySummaryFilter.allCases) { filter in
                        FilterChip(title: filter.displayName, isSelected: selectedDayFilter == filter) {
                            selectedDayFilter = filter
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            HStack {
                Label("\(daySummaries.count) days", systemImage: "calendar")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.stepMuted)
                Spacer()
                Picker("Sort days", selection: $selectedDaySort) {
                    ForEach(DailySummarySort.allCases) { sort in
                        Text(sort.displayName).tag(sort)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.stepAccent)
            }
        }
        .metricCard()
    }

    private var workoutsList: some View {
        VStack(alignment: .leading, spacing: 16) {
            filterStrip

            if filteredWorkouts.isEmpty {
                ContentUnavailableView(
                    "No activities",
                    systemImage: StepReceiptSymbol.steps,
                    description: Text("Try a different filter or connect Apple Health.")
                )
                .padding(.top, 80)
            } else {
                ForEach(filteredWorkouts) { workout in
                    NavigationLink {
                        WorkoutDetailView(workout: workout)
                    } label: {
                        WorkoutRow(workout: workout)
                            .foregroundStyle(Color.stepInk)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: selectedKind == nil) {
                    selectedKind = nil
                }
                ForEach(ActivityKind.allCases) { kind in
                    FilterChip(title: kind.displayName, isSelected: selectedKind == kind) {
                        selectedKind = kind
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

enum ActivityHistoryMode: String, CaseIterable, Identifiable {
    case days
    case workouts

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .days: "Days"
        case .workouts: "Workouts"
        }
    }
}

struct DaySummaryRow: View {
    let summary: DailyActivitySummary
    let distanceUnit: DistanceUnit

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(summary.dateStart, format: .dateTime.weekday(.abbreviated))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.stepAccent)
                Text(summary.dateStart, format: .dateTime.day())
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.stepInk)
            }
            .frame(width: 44)

            VStack(alignment: .leading, spacing: 5) {
                Text("\(summary.steps.formatted()) steps")
                    .font(.headline)
                    .foregroundStyle(Color.stepInk)
                    .lineLimit(1)
                Text("\(ActivityFormatting.formattedDistance(from: summary.distanceMeters, unit: distanceUnit)) · \(ActivityFormatting.formattedCalories(summary.activeEnergyKilocalories)) · \(ActivityFormatting.formattedMinutes(summary.workoutMinutes))")
                    .font(.caption)
                    .foregroundStyle(Color.stepMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            ProgressRing(progress: summary.stepGoalProgress)
                .frame(width: 42, height: 42)
        }
        .padding(14)
        .background(Color.stepSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct DaySummaryDetailView: View {
    @EnvironmentObject private var repository: ActivityRepository
    let summary: DailyActivitySummary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(summary.dateStart, format: .dateTime.weekday(.wide).month(.wide).day().year())
                        .font(.title2.weight(.bold))
                    Text("\(summary.steps.formatted()) steps · \(Int((summary.stepGoalProgress * 100).rounded()))% of goal")
                        .font(.headline)
                        .foregroundStyle(Color.stepMuted)
                }
                .metricCard()

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    MetricTile(title: "Distance", value: ActivityFormatting.formattedDistance(from: summary.distanceMeters, unit: repository.preferences.distanceUnit), icon: StepReceiptSymbol.distance)
                    MetricTile(title: "Active Burn", value: ActivityFormatting.formattedCalories(summary.activeEnergyKilocalories), icon: StepReceiptSymbol.activeEnergy)
                    MetricTile(title: "Flights", value: "\(summary.flightsClimbed)", icon: StepReceiptSymbol.stairClimbing)
                    MetricTile(title: "Workout", value: ActivityFormatting.formattedMinutes(summary.workoutMinutes), icon: StepReceiptSymbol.workout)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Workouts")
                        .font(.headline)
                    if summary.workouts.isEmpty {
                        Text("No workouts logged for this day.")
                            .font(.subheadline)
                            .foregroundStyle(Color.stepMuted)
                    } else {
                        ForEach(summary.workouts) { workout in
                            NavigationLink {
                                WorkoutDetailView(workout: workout)
                            } label: {
                                WorkoutRow(workout: workout)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .metricCard()
            }
            .padding(16)
        }
        .background(Color.stepBackground)
        .navigationTitle("Day")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await repository.selectDate(summary.dateStart)
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.stepAccent : Color.stepSurface)
                .foregroundStyle(isSelected ? .white : Color.stepInk)
                .clipShape(Capsule())
        }
    }
}

struct WorkoutRow: View {
    let workout: WorkoutActivity
    private var style: WorkoutVisualStyle {
        WorkoutVisualStyle(kind: workout.type)
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(style.accent)
                .frame(width: 34, height: 34)
                .background(style.accent.opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
                Text(workout.startDate, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(Color.stepMuted)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(ActivityFormatting.formattedMinutes(workout.durationMinutes))
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                if let burn = workout.activeEnergyKilocalories {
                    Text(ActivityFormatting.formattedCalories(burn))
                        .font(.caption)
                        .foregroundStyle(Color.stepMuted)
                        .lineLimit(1)
                } else if let environment = workout.environment {
                    Text(environment.displayName)
                        .font(.caption)
                        .foregroundStyle(Color.stepMuted)
                        .lineLimit(1)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(14)
        .background(Color.stepSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var iconName: String {
        style.icon
    }
}
