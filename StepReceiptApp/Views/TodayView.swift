import Charts
import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var repository: ActivityRepository

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let summary = repository.todaySummary {
                        dateControls
                        todayHeader(summary)
                        hourlyChart(summary)
                        metricGrid(summary)
                        workoutSection(summary)
                        timetable(summary)
                    } else {
                        ProgressView("Loading activity")
                            .frame(maxWidth: .infinity, minHeight: 260)
                    }
                }
                .padding(16)
            }
            .safeAreaPadding(.bottom, 84)
            .background(Color.stepBackground)
            .navigationTitle(selectedNavigationTitle)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await repository.refresh() }
                    } label: {
                        Image(systemName: StepReceiptSymbol.refresh)
                    }
                    .accessibilityLabel("Refresh")
                }
            }
        }
    }

    private var dateControls: some View {
        HStack(spacing: 10) {
            Button {
                Task { await repository.selectDate(Calendar.current.date(byAdding: .day, value: -1, to: repository.selectedDate) ?? repository.selectedDate) }
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.bordered)
            .disabled(!canMoveBackward)

            DatePicker(
                "Activity date",
                selection: Binding(
                    get: { repository.selectedDate },
                    set: { newDate in
                        Task { await repository.selectDate(newDate) }
                    }
                ),
                in: repository.selectableDateRange(),
                displayedComponents: .date
            )
            .labelsHidden()
            .frame(maxWidth: .infinity)

            Button {
                Task { await repository.selectDate(Calendar.current.date(byAdding: .day, value: 1, to: repository.selectedDate) ?? repository.selectedDate) }
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.bordered)
            .disabled(!canMoveForward)
        }
        .metricCard()
    }

    private func todayHeader(_ summary: DailyActivitySummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(summary.steps.formatted())")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.stepInk)
                        .contentTransition(.numericText())
                    Text("\(summary.dateStart, format: .dateTime.weekday(.wide).month(.abbreviated).day()) · of \(summary.goals.stepsPerDay.formatted()) steps")
                        .font(.subheadline)
                        .foregroundStyle(Color.stepMuted)
                }
                Spacer()
                ProgressRing(progress: summary.stepGoalProgress)
                    .frame(width: 72, height: 72)
            }

            Text(goalStatusText(for: summary))
                .font(.headline)
                .foregroundStyle(summary.stepGoalProgress >= 1 ? Color.stepAccent : Color.stepInk)
        }
        .metricCard()
    }

    private func hourlyChart(_ summary: DailyActivitySummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hourly Steps")
                .font(.headline)
                .foregroundStyle(Color.stepInk)

            if summary.buckets.isEmpty {
                Text("No hourly samples for this day.")
                    .font(.subheadline)
                    .foregroundStyle(Color.stepMuted)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            } else {
                Chart(summary.buckets) { bucket in
                    BarMark(
                        x: .value("Hour", bucket.startDate, unit: .hour),
                        y: .value("Steps", bucket.steps)
                    )
                    .foregroundStyle(Color.stepAccent.gradient)
                }
                .frame(height: 170)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
        .metricCard()
    }

    private func metricGrid(_ summary: DailyActivitySummary) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            if repository.preferences.shows(.distance) {
                MetricTile(
                    title: DashboardMetric.distance.displayName,
                    value: ActivityFormatting.formattedDistance(from: summary.distanceMeters, unit: repository.preferences.distanceUnit),
                    icon: StepReceiptSymbol.distance
                )
            }
            if repository.preferences.shows(.activeEnergy) {
                MetricTile(
                    title: DashboardMetric.activeEnergy.displayName,
                    value: ActivityFormatting.formattedCalories(summary.activeEnergyKilocalories),
                    icon: StepReceiptSymbol.activeEnergy
                )
            }
            if repository.preferences.shows(.flights) {
                MetricTile(title: DashboardMetric.flights.displayName, value: "\(summary.flightsClimbed)", icon: StepReceiptSymbol.stairClimbing)
            }
            if repository.preferences.shows(.workoutMinutes) {
                MetricTile(
                    title: DashboardMetric.workoutMinutes.displayName,
                    value: ActivityFormatting.formattedMinutes(summary.workoutMinutes),
                    icon: StepReceiptSymbol.workout
                )
            }
        }
    }

    private func workoutSection(_ summary: DailyActivitySummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Workouts")
                    .font(.headline)
                Spacer()
                Text("\(summary.workouts.count)")
                    .foregroundStyle(Color.stepMuted)
            }

            if summary.workouts.isEmpty {
                Text("No workouts logged for this day.")
                    .font(.subheadline)
                    .foregroundStyle(Color.stepMuted)
            } else {
                ForEach(summary.workouts.prefix(3)) { workout in
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

    private func timetable(_ summary: DailyActivitySummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timetable")
                .font(.headline)

            if summary.buckets.isEmpty {
                Text("No timetable entries for this day.")
                    .font(.subheadline)
                    .foregroundStyle(Color.stepMuted)
            } else {
                ForEach(summary.buckets) { bucket in
                    HStack(spacing: 12) {
                        Text(bucket.startDate, format: .dateTime.hour())
                            .font(.caption)
                            .foregroundStyle(Color.stepMuted)
                            .frame(width: 58, alignment: .leading)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(bucket.steps.formatted()) steps")
                                .font(.subheadline.weight(.semibold))
                            Text("\(ActivityFormatting.formattedDistance(from: bucket.distanceMeters, unit: repository.preferences.distanceUnit)) · \(ActivityFormatting.formattedCalories(bucket.activeEnergyKilocalories))")
                                .font(.caption)
                                .foregroundStyle(Color.stepMuted)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .metricCard()
    }

    private func goalStatusText(for summary: DailyActivitySummary) -> String {
        guard summary.stepGoalProgress < 1 else {
            return "Goal cleared. Keep the streak intact."
        }

        let remainingSteps = max(0, summary.goals.stepsPerDay - summary.steps)
        return "\(remainingSteps.formatted()) steps left."
    }

    private var canMoveForward: Bool {
        Calendar.current.startOfDay(for: repository.selectedDate) < repository.selectableDateRange().upperBound
    }

    private var canMoveBackward: Bool {
        Calendar.current.startOfDay(for: repository.selectedDate) > repository.selectableDateRange().lowerBound
    }

    private var selectedNavigationTitle: String {
        Calendar.current.isDateInToday(repository.selectedDate) ? "Today" : "Day"
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.stepAccent)
                .frame(width: 22, height: 22, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.stepInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Color.stepMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .metricCard()
    }
}

struct ProgressRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.stepAccent.opacity(0.18), lineWidth: 10)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(Color.stepAccent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int((min(1, max(0, progress)) * 100).rounded()))%")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.stepInk)
        }
    }
}
