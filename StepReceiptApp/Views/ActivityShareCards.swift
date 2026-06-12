import SwiftUI

struct WorkoutShareCard: View {
    let workout: WorkoutActivity
    let distanceUnit: DistanceUnit
    let tag: String?

    init(workout: WorkoutActivity, distanceUnit: DistanceUnit, tag: String? = nil) {
        self.workout = workout
        self.distanceUnit = distanceUnit
        self.tag = tag
    }

    private var style: WorkoutVisualStyle {
        WorkoutVisualStyle(kind: workout.type)
    }

    private var metrics: [ShareMetric] {
        WorkoutShareFormatter.metrics(for: workout, distanceUnit: distanceUnit)
    }

    private var zones: [HeartRateZoneBreakdown] {
        HeartRateZoneBreakdown.zones(for: workout)
    }

    private var totalZoneSeconds: TimeInterval {
        zones.reduce(0) { $0 + $1.durationSeconds }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            metricGrid

            if workout.averageHeartRateBPM != nil || workout.maxHeartRateBPM != nil {
                heartRateStrip
            }

            if totalZoneSeconds > 0 {
                zoneSummary
            }

            footer
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [style.accent.opacity(0.18), Color.stepSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(style.accent.opacity(0.20), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: style.icon)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(style.accent)
                .frame(width: 54, height: 54)
                .background(style.accent.opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("Workout Receipt")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(style.accent)
                Text(tag ?? workout.displayTitle)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.stepInk)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                if tag != nil {
                    Text(workout.displayTitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(style.accent)
                        .lineLimit(1)
                }
                Text(workout.startDate, format: .dateTime.weekday(.wide).month(.wide).day().hour().minute())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.stepMuted)
                    .lineLimit(2)
            }
            .layoutPriority(1)
        }
    }

    private var metricGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
            ForEach(metrics) { metric in
                ShareMetricTile(metric: metric)
            }
        }
    }

    private var heartRateStrip: some View {
        HStack(spacing: 10) {
            shareHeartRateStat("Avg HR", workout.averageHeartRateBPM, Color(red: 1.0, green: 0.28, blue: 0.30))
            shareHeartRateStat("Max HR", workout.maxHeartRateBPM, Color(red: 1.0, green: 0.28, blue: 0.30))
        }
    }

    private var zoneSummary: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("Zone Time", systemImage: "heart.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.stepInk)
                Spacer()
                Text(ActivityFormatting.formattedDuration(totalZoneSeconds))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Color.stepMuted)
            }

            VStack(spacing: 7) {
                ForEach(zones) { zone in
                    HStack(spacing: 8) {
                        Text("Z\(zone.level)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(zone.color)
                            .frame(width: 20, alignment: .leading)

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(zone.color.opacity(0.13))
                                Capsule()
                                    .fill(zone.color.opacity(0.78))
                                    .frame(width: proxy.size.width * zone.durationSeconds / max(1, totalZoneSeconds))
                            }
                        }
                        .frame(height: 8)

                        Text(ActivityFormatting.formattedDuration(zone.durationSeconds))
                            .font(.caption2.monospacedDigit().weight(.semibold))
                            .foregroundStyle(Color.stepMuted)
                            .frame(width: 54, alignment: .trailing)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.stepSurface.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var footer: some View {
        HStack {
            Text(WorkoutShareFormatter.caption(for: workout, distanceUnit: distanceUnit))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.stepMuted)
                .lineLimit(2)
            Spacer()
            Text("StepReceipt")
                .font(.caption.weight(.bold))
                .foregroundStyle(style.accent)
        }
    }

    private func shareHeartRateStat(_ title: String, _ value: Double?, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "heart.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(value.map { "\(Int($0.rounded())) bpm" } ?? "-- bpm")
                    .font(.headline.monospacedDigit().weight(.bold))
                    .foregroundStyle(Color.stepInk)
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.stepMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.stepSurface.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct DayShareCard: View {
    let summary: DailyActivitySummary
    let distanceUnit: DistanceUnit
    let workoutTags: [String: String]

    init(summary: DailyActivitySummary, distanceUnit: DistanceUnit, workoutTags: [String: String] = [:]) {
        self.summary = summary
        self.distanceUnit = distanceUnit
        self.workoutTags = workoutTags
    }

    private var topWorkouts: [WorkoutActivity] {
        Array(summary.workouts.prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DAY RECEIPT")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.stepAccent)
                    Text(summary.dateStart, format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.stepInk)
                    Text("\(summary.steps.formatted()) steps")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.stepInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 0)

                ProgressRing(progress: summary.stepGoalProgress)
                    .frame(width: 58, height: 58)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                ShareMetricTile(metric: ShareMetric("Distance", ActivityFormatting.formattedDistance(from: summary.distanceMeters, unit: distanceUnit), StepReceiptSymbol.distance, Color.stepDistance))
                ShareMetricTile(metric: ShareMetric("Active Burn", ActivityFormatting.formattedCalories(summary.activeEnergyKilocalories), StepReceiptSymbol.activeEnergy, Color.stepEnergy))
                ShareMetricTile(metric: ShareMetric("Workout", ActivityFormatting.formattedMinutes(summary.workoutMinutes), StepReceiptSymbol.workout, Color.stepAccent))
                ShareMetricTile(metric: ShareMetric("Flights", summary.flightsClimbed.formatted(), StepReceiptSymbol.stairClimbing, Color(red: 0.640, green: 0.430, blue: 1.000)))
            }

            if !topWorkouts.isEmpty {
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

                    VStack(spacing: 8) {
                        ForEach(topWorkouts) { workout in
                            DayShareWorkoutRow(
                                workout: workout,
                                distanceUnit: distanceUnit,
                                tag: workoutTags[workout.sourceIdentifier]
                            )
                        }
                    }
                }
                .padding(12)
                .background(Color.stepSurface.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            HStack {
                Text(dayCaption)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.stepMuted)
                    .lineLimit(2)
                Spacer()
                Text("StepReceipt")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.stepAccent)
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.stepAccent.opacity(0.16), Color.stepSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.stepAccent.opacity(0.18), lineWidth: 1)
        )
    }

    private var dayCaption: String {
        if summary.stepGoalProgress >= 1 {
            return "Goal cleared with \(ActivityFormatting.formattedMinutes(summary.workoutMinutes)) logged."
        }

        let remaining = max(0, summary.goals.stepsPerDay - summary.steps)
        return "\(remaining.formatted()) steps left toward the daily goal."
    }
}

struct ShareMetric: Identifiable {
    let id: String
    let title: String
    let value: String
    let icon: String
    let color: Color

    init(_ title: String, _ value: String, _ icon: String, _ color: Color) {
        self.id = "\(title)-\(value)"
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
    }
}

struct ShareMetricTile: View {
    let metric: ShareMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: metric.icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(metric.color)
                    .frame(width: 20, height: 20)
                    .background(metric.color.opacity(0.14))
                    .clipShape(Circle())

                Text(metric.title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.stepMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }

            Text(metric.value)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(Color.stepInk)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .frame(minHeight: 70, alignment: .topLeading)
        .background(Color.stepSurface.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct DayShareWorkoutRow: View {
    let workout: WorkoutActivity
    let distanceUnit: DistanceUnit
    let tag: String?

    private var style: WorkoutVisualStyle {
        WorkoutVisualStyle(kind: workout.type)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: style.icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(style.accent)
                .frame(width: 28, height: 28)
                .background(style.accent.opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(tag ?? workout.displayTitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.stepInk)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.stepMuted)
            }
            .layoutPriority(1)

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 2) {
                Text(ActivityFormatting.formattedMinutes(workout.durationMinutes))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.stepInk)
                    .lineLimit(1)
                Text(secondaryText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.stepMuted)
                    .lineLimit(1)
            }
        }
    }

    private var subtitle: String {
        let timeText = workout.startDate.formatted(date: .omitted, time: .shortened)
        guard tag != nil else { return timeText }
        return "\(workout.displayTitle) · \(timeText)"
    }

    private var secondaryText: String {
        var pieces: [String] = []
        if let burn = workout.activeEnergyKilocalories {
            pieces.append(ActivityFormatting.formattedCalories(burn))
        }
        if let distance = workout.distanceMeters, distance > 0 {
            pieces.append(ActivityFormatting.formattedDistance(from: distance, unit: distanceUnit))
        }
        if let average = workout.averageHeartRateBPM {
            pieces.append("\(Int(average.rounded())) bpm")
        }
        if pieces.isEmpty {
            pieces.append(workout.sourceName)
        }
        return pieces.prefix(3).joined(separator: " · ")
    }
}

private enum WorkoutShareFormatter {
    static func metrics(for workout: WorkoutActivity, distanceUnit: DistanceUnit) -> [ShareMetric] {
        var metrics: [ShareMetric] = [
            ShareMetric("Duration", ActivityFormatting.formattedDuration(workout.durationMinutes * 60), StepReceiptSymbol.workout, WorkoutVisualStyle(kind: workout.type).accent)
        ]

        switch workout.type {
        case .stairClimbing, .elliptical:
            appendEnergyAndEffort(to: &metrics, workout: workout)
            appendBurnRate(to: &metrics, workout: workout)
            appendStepsOrDistance(to: &metrics, workout: workout, distanceUnit: distanceUnit)
        case .strengthTraining, .yoga:
            appendEnergyAndEffort(to: &metrics, workout: workout)
            appendBurnRate(to: &metrics, workout: workout)
            appendTotalEnergy(to: &metrics, workout: workout)
        case .walking, .running, .hiking:
            appendDistance(to: &metrics, workout: workout, distanceUnit: distanceUnit)
            appendPace(to: &metrics, workout: workout, distanceUnit: distanceUnit)
            appendEnergyAndEffort(to: &metrics, workout: workout)
            appendSteps(to: &metrics, workout: workout)
            appendWeather(to: &metrics, workout: workout)
        default:
            appendDistance(to: &metrics, workout: workout, distanceUnit: distanceUnit)
            appendEnergyAndEffort(to: &metrics, workout: workout)
            appendSteps(to: &metrics, workout: workout)
        }

        return Array(metrics.prefix(8))
    }

    static func caption(for workout: WorkoutActivity, distanceUnit: DistanceUnit) -> String {
        var pieces = [ActivityFormatting.formattedMinutes(workout.durationMinutes)]
        if let burn = workout.activeEnergyKilocalories {
            pieces.append(ActivityFormatting.formattedCalories(burn))
        }
        if let distance = workout.distanceMeters, distance > 0 {
            pieces.append(ActivityFormatting.formattedDistance(from: distance, unit: distanceUnit))
        }
        if let average = workout.averageHeartRateBPM {
            pieces.append("\(Int(average.rounded())) bpm avg")
        }
        return pieces.joined(separator: " · ")
    }

    private static func appendEnergyAndEffort(to metrics: inout [ShareMetric], workout: WorkoutActivity) {
        if let burn = workout.activeEnergyKilocalories {
            metrics.append(ShareMetric("Active Burn", ActivityFormatting.formattedCalories(burn), StepReceiptSymbol.activeEnergy, Color.stepEnergy))
        }

        let effort = WorkoutEffort(workout: workout)
        metrics.append(ShareMetric("Effort", effort.title, "bolt.heart", effort.color))
    }

    private static func appendTotalEnergy(to metrics: inout [ShareMetric], workout: WorkoutActivity) {
        guard let total = workout.totalEnergyKilocalories,
              total > (workout.activeEnergyKilocalories ?? 0) + 1 else { return }
        metrics.append(ShareMetric("Total Burn", ActivityFormatting.formattedCalories(total), "flame.fill", Color.stepEnergy))
    }

    private static func appendBurnRate(to metrics: inout [ShareMetric], workout: WorkoutActivity) {
        guard let burn = workout.activeEnergyKilocalories, workout.durationMinutes > 0 else { return }
        metrics.append(ShareMetric("Burn Rate", String(format: "%.1f kcal/min", burn / workout.durationMinutes), "flame.circle", Color.stepEnergy))
    }

    private static func appendDistance(to metrics: inout [ShareMetric], workout: WorkoutActivity, distanceUnit: DistanceUnit) {
        guard let distance = workout.distanceMeters, distance > 0 else { return }
        metrics.append(ShareMetric("Distance", ActivityFormatting.formattedDistance(from: distance, unit: distanceUnit), StepReceiptSymbol.distance, Color.stepDistance))
    }

    private static func appendSteps(to metrics: inout [ShareMetric], workout: WorkoutActivity) {
        guard let steps = workout.steps else { return }
        metrics.append(ShareMetric("Steps", steps.formatted(), StepReceiptSymbol.stepPrints, Color.stepAccent))
    }

    private static func appendStepsOrDistance(to metrics: inout [ShareMetric], workout: WorkoutActivity, distanceUnit: DistanceUnit) {
        if let steps = workout.steps {
            metrics.append(ShareMetric("Steps", steps.formatted(), StepReceiptSymbol.stepPrints, Color.stepAccent))
        } else {
            appendDistance(to: &metrics, workout: workout, distanceUnit: distanceUnit)
        }
    }

    private static func appendPace(to metrics: inout [ShareMetric], workout: WorkoutActivity, distanceUnit: DistanceUnit) {
        guard let pace = paceText(for: workout, distanceUnit: distanceUnit) else { return }
        metrics.append(ShareMetric("Pace", pace, "speedometer", Color.stepDistance))
    }

    private static func appendWeather(to metrics: inout [ShareMetric], workout: WorkoutActivity) {
        let temperature = workout.weatherTemperatureCelsius.map { "\(Int(($0 * 9 / 5 + 32).rounded())) F" }
        let humidity = workout.weatherHumidityPercent.map { "\(Int($0.rounded()))%" }
        guard let value = [temperature, humidity].compactMap({ $0 }).joined(separator: "  ").nilIfEmpty else { return }
        metrics.append(ShareMetric("Weather", value, "cloud.sun", Color.stepDistance))
    }

    private static func paceText(for workout: WorkoutActivity, distanceUnit: DistanceUnit) -> String? {
        guard let distance = workout.distanceMeters, distance > 0, workout.durationMinutes > 0 else { return nil }
        let unitDistance = distanceUnit == .miles ? ActivityFormatting.miles(from: distance) : ActivityFormatting.kilometers(from: distance)
        guard unitDistance > 0 else { return nil }
        let secondsPerUnit = workout.durationMinutes * 60 / unitDistance
        let totalSeconds = max(0, Int(secondsPerUnit.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d %@", minutes, seconds, distanceUnit == .miles ? "/mi" : "/km")
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
