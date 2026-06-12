import SwiftUI

struct ActivityHistoryView: View {
    @EnvironmentObject private var repository: ActivityRepository
    @State private var selectedMode: ActivityHistoryMode = .days
    @State private var selectedWorkoutFilter: ActivityWorkoutFilter = .all
    @State private var selectedDayFilter: DailySummaryFilter = .all
    @State private var selectedDaySort: DailySummarySort = .newest

    private var filteredWorkouts: [WorkoutActivity] {
        repository.filteredWorkouts(kind: nil).filter(selectedWorkoutFilter.matches)
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
                        WorkoutRow(workout: workout, tag: repository.workoutTag(for: workout))
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
                ForEach(ActivityWorkoutFilter.allCases) { filter in
                    FilterChip(title: filter.displayName, isSelected: selectedWorkoutFilter == filter) {
                        selectedWorkoutFilter = filter
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

enum ActivityWorkoutFilter: String, CaseIterable, Identifiable {
    case all
    case stairClimber
    case strength
    case outdoorWalk
    case indoorWalk
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: "All"
        case .stairClimber: "Stairs"
        case .strength: "Strength"
        case .outdoorWalk: "Outdoor Walk"
        case .indoorWalk: "Indoor Walk"
        case .other: "Other"
        }
    }

    func matches(_ workout: WorkoutActivity) -> Bool {
        switch self {
        case .all:
            true
        case .stairClimber:
            workout.type == .stairClimbing
        case .strength:
            workout.type == .strengthTraining
        case .outdoorWalk:
            workout.type == .walking && workout.environment == .outdoor
        case .indoorWalk:
            workout.type == .walking && workout.environment == .indoor
        case .other:
            !Self.isFrequent(workout)
        }
    }

    private static func isFrequent(_ workout: WorkoutActivity) -> Bool {
        workout.type == .stairClimbing
            || workout.type == .strengthTraining
            || (workout.type == .walking && workout.environment == .outdoor)
            || (workout.type == .walking && workout.environment == .indoor)
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
    @State private var shareImage: ShareImage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(summary.dateStart, format: .dateTime.weekday(.wide).month(.wide).day().year())
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.stepInk)
                    Text("\(summary.steps.formatted()) steps · \(Int((summary.stepGoalProgress * 100).rounded()))% of goal")
                        .font(.headline)
                        .foregroundStyle(Color.stepMuted)
                }
                .metricCard()

                if !summary.workouts.isEmpty {
                    topWorkoutLinks
                }

                DayShareCard(
                    summary: summary,
                    distanceUnit: repository.preferences.distanceUnit,
                    workoutTags: repository.workoutTags
                )

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
                                WorkoutRow(workout: workout, tag: repository.workoutTag(for: workout))
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    shareImage = ShareImageRenderer.render {
                        DayShareCard(
                            summary: summary,
                            distanceUnit: repository.preferences.distanceUnit,
                            workoutTags: repository.workoutTags
                        )
                        .frame(width: 390)
                        .padding(18)
                        .background(Color.stepBackground)
                    }
                } label: {
                    Image(systemName: StepReceiptSymbol.share)
                }
                .accessibilityLabel("Share day")
            }
        }
        .sheet(item: $shareImage) { shareImage in
            ShareSheet(items: [shareImage.image])
        }
        .task {
            await repository.selectDate(summary.dateStart)
        }
    }

    private var topWorkoutLinks: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Workouts")
                    .font(.headline)
                    .foregroundStyle(Color.stepInk)
                Spacer()
                Text("\(summary.workouts.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.stepMuted)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(summary.workouts.prefix(8)) { workout in
                        NavigationLink {
                            WorkoutDetailView(workout: workout)
                        } label: {
                            DayWorkoutQuickLink(
                                workout: workout,
                                tag: repository.workoutTag(for: workout),
                                distanceUnit: repository.preferences.distanceUnit
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
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
    let tag: String?

    init(workout: WorkoutActivity, tag: String? = nil) {
        self.workout = workout
        self.tag = tag
    }

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
                Text(tag ?? workout.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
                Text(subtitle)
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
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("workout-row-\(workout.sourceIdentifier)")
    }

    private var iconName: String {
        style.icon
    }

    private var subtitle: String {
        let dateText = workout.startDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
        guard tag != nil else { return dateText }
        return "\(workout.displayTitle) · \(dateText)"
    }
}

private struct DayWorkoutQuickLink: View {
    let workout: WorkoutActivity
    let tag: String?
    let distanceUnit: DistanceUnit

    private var style: WorkoutVisualStyle {
        WorkoutVisualStyle(kind: workout.type)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: style.icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(style.accent)
                    .frame(width: 30, height: 30)
                    .background(style.accent.opacity(0.14))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(tag ?? workout.displayTitle)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.stepInk)
                        .lineLimit(1)
                    Text(tag == nil ? workout.startDate.formatted(date: .omitted, time: .shortened) : workout.displayTitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.stepMuted)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 6) {
                Label(ActivityFormatting.formattedMinutes(workout.durationMinutes), systemImage: "clock")
                if let burn = workout.activeEnergyKilocalories {
                    Label(ActivityFormatting.formattedCalories(burn), systemImage: StepReceiptSymbol.activeEnergy)
                } else if let distance = workout.distanceMeters, distance > 0 {
                    Label(ActivityFormatting.formattedDistance(from: distance, unit: distanceUnit), systemImage: StepReceiptSymbol.distance)
                }
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.stepMuted)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
        }
        .frame(width: 180, alignment: .topLeading)
        .frame(minHeight: 92, alignment: .topLeading)
        .padding(12)
        .background(Color.stepSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(style.accent.opacity(0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("day-workout-\(workout.sourceIdentifier)")
    }
}
