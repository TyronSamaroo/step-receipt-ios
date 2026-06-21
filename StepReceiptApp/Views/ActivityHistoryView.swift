import SwiftUI

struct ActivityHistoryView: View {
    @EnvironmentObject private var repository: ActivityRepository
    @AppStorage(AppViewPreferenceKey.activityMode) private var selectedModeRaw = AppViewPreferenceDefault.activityMode
    @AppStorage(AppViewPreferenceKey.activityWorkoutFilter) private var selectedWorkoutFilterRaw = AppViewPreferenceDefault.activityWorkoutFilter
    @AppStorage(AppViewPreferenceKey.activityDayFilter) private var selectedDayFilterRaw = AppViewPreferenceDefault.activityDayFilter
    @AppStorage(AppViewPreferenceKey.activityDaySort) private var selectedDaySortRaw = AppViewPreferenceDefault.activityDaySort

    private var selectedMode: ActivityHistoryMode {
        ActivityHistoryMode(rawValue: selectedModeRaw) ?? .days
    }

    private var selectedWorkoutFilter: ActivityWorkoutFilter {
        ActivityWorkoutFilter(rawValue: selectedWorkoutFilterRaw) ?? .all
    }

    private var selectedDayFilter: DailySummaryFilter {
        DailySummaryFilter(rawValue: selectedDayFilterRaw) ?? .all
    }

    private var selectedDaySort: DailySummarySort {
        DailySummarySort(rawValue: selectedDaySortRaw) ?? .newest
    }

    private var selectedModeBinding: Binding<ActivityHistoryMode> {
        Binding(
            get: { selectedMode },
            set: { selectedModeRaw = $0.rawValue }
        )
    }

    private var selectedDaySortBinding: Binding<DailySummarySort> {
        Binding(
            get: { selectedDaySort },
            set: { selectedDaySortRaw = $0.rawValue }
        )
    }

    private var filteredWorkouts: [WorkoutActivity] {
        repository.filteredWorkouts(kind: nil).filter(selectedWorkoutFilter.matches)
    }

    private var daySummaries: [DailyActivitySummary] {
        repository.filteredDailySummaries(filter: selectedDayFilter, sort: selectedDaySort)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("History", selection: selectedModeBinding) {
                        ForEach(ActivityHistoryMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("activity-history-mode-picker")

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
            .refreshable {
                await repository.refresh()
            }
        }
    }

    private var daysList: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                    .accessibilityIdentifier("activity-day-row-\(summary.id)")
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
                            selectedDayFilterRaw = filter.rawValue
                        }
                        .accessibilityIdentifier("activity-day-filter-\(filter.rawValue)")
                    }
                }
                .padding(.vertical, 4)
            }

            HStack {
                Label("\(daySummaries.count) days", systemImage: "calendar")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.stepMuted)
                Spacer()
                Picker("Sort days", selection: selectedDaySortBinding) {
                    ForEach(DailySummarySort.allCases) { sort in
                        Text(sort.displayName).tag(sort)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.stepAccent)
                .accessibilityIdentifier("activity-day-sort-menu")
            }
        }
        .metricCard()
    }

    private var workoutsList: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                        selectedWorkoutFilterRaw = filter.rawValue
                    }
                    .accessibilityIdentifier("activity-workout-filter-\(filter.rawValue)")
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

    private var dayPeriod: PeriodActivitySummary {
        repository.periodSummary(scope: .day, containing: summary.dateStart)
    }

    private var cardioInsight: CardioPeriodInsight {
        dayPeriod.cardioInsight
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
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

                dayTimeline

                if cardioInsight.hasCardio {
                    dayCardioSection
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
                        .font(.subheadline.weight(.bold))
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
            .accessibilityIdentifier("day-detail-screen-\(summary.id)")
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
                    .font(.subheadline.weight(.bold))
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

    private var dayTimeline: some View {
        let activeHourCount = summary.buckets.filter { $0.steps > 0 }.count
        let peakHourStart = TodayQuickDigestBuilder.digest(for: summary).peakHourStart

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Hourly Timeline", systemImage: "clock")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.stepInk)
                Spacer()
                Text(summary.buckets.isEmpty ? "No buckets" : "\(activeHourCount) active")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.stepMuted)
            }

            if summary.buckets.isEmpty {
                Text("No hourly timeline for this day yet.")
                    .font(.caption)
                    .foregroundStyle(Color.stepMuted)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .center)
            } else {
                CompactHourlyTimetableRows(
                    buckets: summary.buckets,
                    distanceUnit: repository.preferences.distanceUnit,
                    peakHourStart: peakHourStart
                )
            }
        }
        .metricCard()
    }

    private var dayCardioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Cardio", systemImage: "figure.run")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.stepInk)
                Spacer()
                Text("\(cardioInsight.sessionCount) sessions")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.stepMuted)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                MetricTile(title: "Minutes", value: ActivityFormatting.formattedMinutes(cardioInsight.totalMinutes), icon: StepReceiptSymbol.workout)
                MetricTile(title: "Distance", value: ActivityFormatting.formattedDistance(from: cardioInsight.totalDistanceMeters, unit: repository.preferences.distanceUnit), icon: StepReceiptSymbol.distance)
                MetricTile(title: "Active Burn", value: ActivityFormatting.formattedCalories(cardioInsight.totalActiveEnergyKilocalories), icon: StepReceiptSymbol.activeEnergy)
                MetricTile(title: "Avg HR", value: averageHeartRateText, icon: "heart.fill")
            }
        }
        .metricCard()
    }

    private var averageHeartRateText: String {
        guard let bpm = cardioInsight.averageHeartRateBPM else { return "--" }
        return "\(Int(bpm.rounded())) bpm"
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let accessibilityIdentifier: String?
    let action: () -> Void

    init(
        title: String,
        isSelected: Bool,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isSelected = isSelected
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }

    var body: some View {
        let chip = Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.stepAccent : Color.stepSurface)
                .foregroundStyle(isSelected ? .white : Color.stepInk)
                .clipShape(Capsule())
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])

        if let accessibilityIdentifier {
            chip.accessibilityIdentifier(accessibilityIdentifier)
        } else {
            chip
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
