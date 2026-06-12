import Charts
import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var repository: ActivityRepository
    @State private var shareImage: ShareImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let summary = repository.todaySummary {
                        todayHero(summary)
                        todayCoach(repository.todayCoachInsights())
                        primaryWorkoutCard(summary)
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        guard let summary = repository.todaySummary else { return }
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
                    .disabled(repository.todaySummary == nil)
                }

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
        .sheet(item: $shareImage) { shareImage in
            ShareSheet(items: [shareImage.image])
        }
    }

    private var screenTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(selectedNavigationTitle)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Color.stepInk)
            Text(repository.selectedDate, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.stepMuted)
        }
        .accessibilityElement(children: .combine)
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
            .tint(Color.stepAccent)
            .foregroundStyle(Color.stepInk)
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

    private func todayHero(_ summary: DailyActivitySummary) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(selectedNavigationTitle)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.stepInk)
                    Text(repository.selectedDate, format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.stepMuted)
                }

                Spacer(minLength: 0)

                weatherPill(summary)
            }

            heroDateControls

            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(summary.steps.formatted())")
                        .font(.system(size: 58, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.stepInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                        .contentTransition(.numericText())
                    Text("of \(summary.goals.stepsPerDay.formatted()) steps")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.stepMuted)
                    Text(goalStatusText(for: summary))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(summary.stepGoalProgress >= 1 ? Color.stepAccent : Color.stepInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                ProgressRing(progress: summary.stepGoalProgress)
                    .frame(width: 114, height: 114)
                    .accessibilityLabel("Step goal progress \(Int((summary.stepGoalProgress * 100).rounded())) percent")
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    heroMetricPill("Distance", ActivityFormatting.formattedDistance(from: summary.distanceMeters, unit: repository.preferences.distanceUnit), StepReceiptSymbol.distance, Color.stepDistance)
                    heroMetricPill("Burn", ActivityFormatting.formattedCalories(summary.activeEnergyKilocalories), StepReceiptSymbol.activeEnergy, Color.stepEnergy)
                    heroMetricPill("Workout", ActivityFormatting.formattedMinutes(summary.workoutMinutes), StepReceiptSymbol.workout, Color.stepAccent)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    heroMetricPill("Distance", ActivityFormatting.formattedDistance(from: summary.distanceMeters, unit: repository.preferences.distanceUnit), StepReceiptSymbol.distance, Color.stepDistance)
                    heroMetricPill("Burn", ActivityFormatting.formattedCalories(summary.activeEnergyKilocalories), StepReceiptSymbol.activeEnergy, Color.stepEnergy)
                    heroMetricPill("Workout", ActivityFormatting.formattedMinutes(summary.workoutMinutes), StepReceiptSymbol.workout, Color.stepAccent)
                }
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    Color.stepSurface,
                    Color.stepAccent.opacity(0.13),
                    Color.stepDistance.opacity(0.09),
                    Color.stepEnergy.opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.stepAccent.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: Color.stepAccent.opacity(0.08), radius: 20, x: 0, y: 12)
        .accessibilityElement(children: .contain)
    }

    private var heroDateControls: some View {
        HStack(spacing: 10) {
            Button {
                Task { await repository.selectDate(Calendar.current.date(byAdding: .day, value: -1, to: repository.selectedDate) ?? repository.selectedDate) }
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(canMoveBackward ? Color.stepAccent : Color.stepMuted.opacity(0.45))
            .background(Color.stepSurface.opacity(0.82))
            .clipShape(Circle())
            .disabled(!canMoveBackward)
            .accessibilityLabel("Previous day")

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
            .tint(Color.stepAccent)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color.stepSurface.opacity(0.82))
            .clipShape(Capsule())

            Button {
                Task { await repository.selectDate(Calendar.current.date(byAdding: .day, value: 1, to: repository.selectedDate) ?? repository.selectedDate) }
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(canMoveForward ? Color.stepAccent : Color.stepMuted.opacity(0.45))
            .background(Color.stepSurface.opacity(0.82))
            .clipShape(Circle())
            .disabled(!canMoveForward)
            .accessibilityLabel("Next day")
        }
    }

    private func weatherPill(_ summary: DailyActivitySummary) -> some View {
        let weather = weatherSummary(for: summary)
        return VStack(alignment: .trailing, spacing: 4) {
            Label(weather?.temperature ?? "-- F", systemImage: "thermometer.sun")
                .foregroundStyle(Color.stepEnergy)
            Label(weather?.humidity ?? "--%", systemImage: "water.waves")
                .foregroundStyle(Color.stepDistance)
        }
        .font(.caption.weight(.bold))
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.stepSurface.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Weather \(weather?.temperature ?? "not available"), humidity \(weather?.humidity ?? "not available")")
    }

    private func heroMetricPill(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 22, height: 22)
                .background(color.opacity(0.16))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.stepInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.stepMuted)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.stepSurface.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func todayCoach(_ insights: [TodayCoachInsight]) -> some View {
        if !insights.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Today Coach", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(Color.stepInk)
                    Spacer()
                    Text("Personal")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.stepAccent)
                }

                VStack(spacing: 10) {
                    ForEach(insights) { insight in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: insight.systemImage)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.stepAccent)
                                .frame(width: 28, height: 28)
                                .background(Color.stepAccent.opacity(0.14))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 3) {
                                Text(insight.title)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color.stepInk)
                                Text(insight.detail)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.stepMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
            .metricCard()
        }
    }

    @ViewBuilder
    private func primaryWorkoutCard(_ summary: DailyActivitySummary) -> some View {
        if let workout = summary.workouts.first {
            let style = WorkoutVisualStyle(kind: workout.type)
            NavigationLink {
                WorkoutDetailView(workout: workout)
            } label: {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: style.icon)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(style.accent)
                            .frame(width: 44, height: 44)
                            .background(style.accent.opacity(0.16))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Today's Workout")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(style.accent)
                            Text(repository.workoutTag(for: workout) ?? workout.displayTitle)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color.stepInk)
                                .lineLimit(2)
                                .minimumScaleFactor(0.82)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.stepMuted)
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            workoutHeroMetric("Duration", ActivityFormatting.formattedDuration(workout.durationMinutes * 60), StepReceiptSymbol.workout, style.accent)
                            if let burn = workout.activeEnergyKilocalories {
                                workoutHeroMetric("Burn", ActivityFormatting.formattedCalories(burn), StepReceiptSymbol.activeEnergy, Color.stepEnergy)
                            }
                            if let averageHeartRate = workout.averageHeartRateBPM {
                                workoutHeroMetric("Avg HR", "\(Int(averageHeartRate.rounded())) bpm", "heart.fill", HeartRateZoneBreakdown.template(for: averageHeartRate).color)
                            }
                        }

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            workoutHeroMetric("Duration", ActivityFormatting.formattedDuration(workout.durationMinutes * 60), StepReceiptSymbol.workout, style.accent)
                            if let burn = workout.activeEnergyKilocalories {
                                workoutHeroMetric("Burn", ActivityFormatting.formattedCalories(burn), StepReceiptSymbol.activeEnergy, Color.stepEnergy)
                            }
                            if let averageHeartRate = workout.averageHeartRateBPM {
                                workoutHeroMetric("Avg HR", "\(Int(averageHeartRate.rounded())) bpm", "heart.fill", HeartRateZoneBreakdown.template(for: averageHeartRate).color)
                            }
                        }
                    }
                }
                .padding(16)
                .background(
                    LinearGradient(
                        colors: [style.accent.opacity(0.14), Color.stepSurface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(style.accent.opacity(0.20), lineWidth: 1)
                )
                .shadow(color: style.accent.opacity(0.08), radius: 14, x: 0, y: 8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Today's Workout \(workout.displayTitle)")
        }
    }

    private func workoutHeroMetric(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 22, height: 22)
                .background(color.opacity(0.14))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.stepInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.stepMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.stepSurface.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func weatherStrip(_ summary: DailyActivitySummary) -> some View {
        if let weather = weatherSummary(for: summary) {
            HStack(spacing: 12) {
                Label("Weather", systemImage: "cloud.sun")
                    .foregroundStyle(Color.stepDistance)
                Spacer(minLength: 0)
                Label(weather.temperature, systemImage: "thermometer.sun")
                    .foregroundStyle(Color.stepEnergy)
                Label(weather.humidity, systemImage: "water.waves")
                    .foregroundStyle(Color.stepDistance)
                    .labelStyle(.titleAndIcon)
            }
            .overlay(alignment: .bottomLeading) {
                Text(weather.source)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.stepMuted.opacity(0.86))
                    .lineLimit(1)
                    .offset(y: 18)
            }
            .font(.subheadline.weight(.bold))
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 20)
            .background(Color.stepSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 6)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Weather \(weather.temperature), humidity \(weather.humidity)")
        }
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
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 4)) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.stepAxisGrid)
                        AxisTick()
                            .foregroundStyle(Color.stepAxis)
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(shortHourLabel(for: date))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.stepAxis)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) {
                        AxisGridLine()
                            .foregroundStyle(Color.stepAxisGrid)
                        AxisTick()
                            .foregroundStyle(Color.stepAxis)
                        AxisValueLabel()
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.stepAxis)
                    }
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
                    icon: StepReceiptSymbol.distance,
                    color: Color.stepDistance
                )
            }
            if repository.preferences.shows(.activeEnergy) {
                MetricTile(
                    title: DashboardMetric.activeEnergy.displayName,
                    value: ActivityFormatting.formattedCalories(summary.activeEnergyKilocalories),
                    icon: StepReceiptSymbol.activeEnergy,
                    color: Color.stepEnergy
                )
            }
            if repository.preferences.shows(.flights) {
                MetricTile(
                    title: DashboardMetric.flights.displayName,
                    value: "\(summary.flightsClimbed)",
                    icon: StepReceiptSymbol.stairClimbing,
                    color: Color(red: 0.640, green: 0.430, blue: 1.000)
                )
            }
            if repository.preferences.shows(.workoutMinutes) {
                MetricTile(
                    title: DashboardMetric.workoutMinutes.displayName,
                    value: ActivityFormatting.formattedMinutes(summary.workoutMinutes),
                    icon: StepReceiptSymbol.workout,
                    color: Color.stepAccent
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
                        WorkoutRow(workout: workout, tag: repository.workoutTag(for: workout))
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

    private func weatherSummary(for summary: DailyActivitySummary) -> (temperature: String, humidity: String, source: String)? {
        guard let workout = summary.workouts.first(where: {
            $0.weatherTemperatureCelsius != nil || $0.weatherHumidityPercent != nil
        }) else {
            return nil
        }

        let temperature = workout.weatherTemperatureCelsius.map { "\(Int(celsiusToFahrenheit($0).rounded())) F" } ?? "-- F"
        let humidity = workout.weatherHumidityPercent.map { "\(Int($0.rounded()))%" } ?? "--%"
        return (temperature, humidity, workout.displayTitle)
    }

    private func celsiusToFahrenheit(_ celsius: Double) -> Double {
        celsius * 9 / 5 + 32
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

    private func shortHourLabel(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        if hour == 0 { return "12a" }
        if hour < 12 { return "\(hour)a" }
        if hour == 12 { return "12p" }
        return "\(hour - 12)p"
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .stepAccent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
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
                .stroke(
                    AngularGradient(
                        colors: [Color.stepAccent, Color.stepDistance, Color.stepEnergy, Color.stepAccent],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text("\(Int((min(1, max(0, progress)) * 100).rounded()))%")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.stepInk)
        }
    }
}
