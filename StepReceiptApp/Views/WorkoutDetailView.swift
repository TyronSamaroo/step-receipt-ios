import SwiftUI

struct WorkoutDetailView: View {
    @EnvironmentObject private var repository: ActivityRepository
    let workout: WorkoutActivity
    @State private var shareImage: ShareImage?

    private var style: WorkoutVisualStyle {
        WorkoutVisualStyle(kind: workout.type)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                WorkoutHero(workout: workout, style: style)
                metricGrid
                insightPanel
                detailPanel
                WorkoutShareCard(workout: workout, distanceUnit: repository.preferences.distanceUnit)
            }
            .padding(16)
        }
        .safeAreaPadding(.bottom, 84)
        .background(Color.stepBackground)
        .navigationTitle(workout.displayTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    shareImage = ShareImageRenderer.render {
                        WorkoutShareCard(workout: workout, distanceUnit: repository.preferences.distanceUnit)
                            .frame(width: 390)
                            .padding(18)
                            .background(Color.stepBackground)
                    }
                } label: {
                    Image(systemName: StepReceiptSymbol.share)
                }
                .accessibilityLabel("Share workout")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareImage) { shareImage in
            ShareSheet(items: [shareImage.image])
        }
    }

    private var metricGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            WorkoutMetricTile(
                title: "Duration",
                value: ActivityFormatting.formattedDuration(workout.durationMinutes * 60),
                icon: StepReceiptSymbol.workout,
                color: style.accent
            )

            if let distance = workout.distanceMeters {
                WorkoutMetricTile(
                    title: "Distance",
                    value: ActivityFormatting.formattedDistance(from: distance, unit: repository.preferences.distanceUnit),
                    icon: StepReceiptSymbol.distance,
                    color: Color.stepDistance
                )
            }

            if let burn = workout.activeEnergyKilocalories {
                WorkoutMetricTile(
                    title: "Active Burn",
                    value: ActivityFormatting.formattedCalories(burn),
                    icon: StepReceiptSymbol.activeEnergy,
                    color: Color.stepEnergy
                )
            }

            if let totalEnergy = workout.totalEnergyKilocalories,
               totalEnergy > (workout.activeEnergyKilocalories ?? 0) + 1 {
                WorkoutMetricTile(
                    title: "Total Energy",
                    value: ActivityFormatting.formattedCalories(totalEnergy),
                    icon: "flame.fill",
                    color: Color.stepEnergy
                )
            }

            if let steps = workout.steps {
                WorkoutMetricTile(
                    title: "Steps",
                    value: steps.formatted(),
                    icon: StepReceiptSymbol.stepPrints,
                    color: Color.stepAccent
                )
            }

            if let pace = paceText {
                WorkoutMetricTile(
                    title: "Pace",
                    value: pace,
                    icon: "speedometer",
                    color: Color.stepDistance
                )
            }
        }
    }

    private var insightPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Workout Snapshot", systemImage: style.icon)
                .font(.headline)
                .foregroundStyle(Color.stepInk)

            Text(primaryInsight)
                .font(.subheadline)
                .foregroundStyle(Color.stepMuted)

            VStack(spacing: 10) {
                if let burnRateText {
                    insightRow("Burn rate", burnRateText, StepReceiptSymbol.activeEnergy, Color.stepEnergy)
                }
                if let cadenceText {
                    insightRow("Cadence", cadenceText, StepReceiptSymbol.stepPrints, Color.stepAccent)
                }
                if let speedText {
                    insightRow("Speed", speedText, "gauge.with.dots.needle.50percent", Color.stepDistance)
                }
            }
        }
        .metricCard()
    }

    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Additional Info")
                .font(.headline)
                .foregroundStyle(Color.stepInk)

            detailRow("Type", workout.displayTitle, style.icon, style.accent)
            if let environment = workout.environment {
                detailRow("Place", environment.displayName, environment == .indoor ? "house" : "sun.max", Color.stepDistance)
            }
            if let weatherText {
                detailRow("Weather", weatherText, "cloud.sun", Color.stepDistance)
            }
            detailRow("Started", workout.startDate.formatted(date: .abbreviated, time: .shortened), "calendar", style.accent)
            detailRow("Ended", workout.endDate.formatted(date: .omitted, time: .shortened), "flag.checkered", style.accent)
            detailRow("Source", workout.sourceName, StepReceiptSymbol.healthCard, Color.stepWarning)
        }
        .metricCard()
    }

    private var primaryInsight: String {
        switch workout.type {
        case .walking:
            if let paceText {
                return "\(workout.displayTitle) at \(paceText)."
            }
            return "\(workout.displayTitle) logged for \(ActivityFormatting.formattedMinutes(workout.durationMinutes))."
        case .running:
            if let paceText {
                return "Run pace: \(paceText)."
            }
            return "Run logged for \(ActivityFormatting.formattedMinutes(workout.durationMinutes))."
        case .stairClimbing:
            if let burnRateText {
                return "Stair session with \(burnRateText.lowercased())."
            }
            return "Stair session logged for \(ActivityFormatting.formattedMinutes(workout.durationMinutes))."
        case .strengthTraining:
            if let burnRateText {
                return "\(workout.displayTitle) with \(burnRateText.lowercased())."
            }
            return "\(workout.displayTitle) logged for \(ActivityFormatting.formattedMinutes(workout.durationMinutes))."
        default:
            return "\(workout.displayTitle) logged from \(workout.sourceName)."
        }
    }

    private var paceText: String? {
        guard let distance = workout.distanceMeters, distance > 0, workout.durationMinutes > 0 else { return nil }
        let unitDistance = repository.preferences.distanceUnit == .miles
            ? ActivityFormatting.miles(from: distance)
            : ActivityFormatting.kilometers(from: distance)
        guard unitDistance > 0 else { return nil }
        let secondsPerUnit = workout.durationMinutes * 60 / unitDistance
        return "\(formattedPace(secondsPerUnit)) \(repository.preferences.distanceUnit == .miles ? "/mi" : "/km")"
    }

    private var speedText: String? {
        guard let distance = workout.distanceMeters, distance > 0, workout.durationMinutes > 0 else { return nil }
        let hours = workout.durationMinutes / 60
        guard hours > 0 else { return nil }
        let unitDistance = repository.preferences.distanceUnit == .miles
            ? ActivityFormatting.miles(from: distance)
            : ActivityFormatting.kilometers(from: distance)
        let suffix = repository.preferences.distanceUnit == .miles ? "mph" : "km/h"
        return String(format: "%.1f %@", unitDistance / hours, suffix)
    }

    private var burnRateText: String? {
        guard let burn = workout.activeEnergyKilocalories, workout.durationMinutes > 0 else { return nil }
        return String(format: "%.1f kcal/min", burn / workout.durationMinutes)
    }

    private var cadenceText: String? {
        guard let steps = workout.steps, workout.durationMinutes > 0 else { return nil }
        return "\(Int((Double(steps) / workout.durationMinutes).rounded())) steps/min"
    }

    private var weatherText: String? {
        let temperature = workout.weatherTemperatureCelsius.map { "\(Int($0.rounded())) C" }
        let humidity = workout.weatherHumidityPercent.map { "\(Int($0.rounded()))%" }
        return [temperature, humidity].compactMap { $0 }.joined(separator: "  ").nilIfEmpty
    }

    private func formattedPace(_ seconds: Double) -> String {
        let totalSeconds = max(0, Int(seconds.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func insightRow(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.14))
                .clipShape(Circle())
            Text(title)
                .foregroundStyle(Color.stepMuted)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.stepInk)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private func detailRow(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(title)
                .foregroundStyle(Color.stepMuted)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(Color.stepInk)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .font(.subheadline)
    }
}

struct WorkoutHero: View {
    let workout: WorkoutActivity
    let style: WorkoutVisualStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: style.icon)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(style.accent)
                    .frame(width: 64, height: 64)
                    .background(style.accent.opacity(0.18))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 6) {
                    Text(workout.displayTitle)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.stepInk)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                    Text(workout.startDate, format: .dateTime.weekday(.wide).month(.wide).day().year().hour().minute())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.stepMuted)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    heroChips
                }
                VStack(alignment: .leading, spacing: 8) {
                    heroChips
                }
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    style.accent.opacity(0.22),
                    Color.stepSurface
                ],
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

    @ViewBuilder
    private var heroChips: some View {
        if let environment = workout.environment {
            heroChip(environment.displayName, systemImage: environment == .indoor ? "house" : "sun.max")
        }
        if workout.weatherTemperatureCelsius != nil || workout.weatherHumidityPercent != nil {
            heroChip("Weather", systemImage: "cloud.sun")
        }
        heroChip(workout.sourceName, systemImage: StepReceiptSymbol.healthCard)
    }

    private func heroChip(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.stepInk)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.stepSurface.opacity(0.68))
            .clipShape(Capsule())
    }
}

struct WorkoutMetricTile: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.stepInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.stepMuted)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.stepSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 7)
    }
}

struct WorkoutShareCard: View {
    let workout: WorkoutActivity
    let distanceUnit: DistanceUnit

    private var style: WorkoutVisualStyle {
        WorkoutVisualStyle(kind: workout.type)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.displayTitle.uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(style.accent)
                    Text("Workout Receipt")
                        .font(.title.weight(.bold))
                        .foregroundStyle(Color.stepInk)
                }
                Spacer()
                Image(systemName: style.icon)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(style.accent)
                    .frame(width: 54, height: 54)
                    .background(style.accent.opacity(0.14))
                    .clipShape(Circle())
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                receiptMetric("Duration", ActivityFormatting.formattedDuration(workout.durationMinutes * 60))
                if let distance = workout.distanceMeters {
                    receiptMetric("Distance", ActivityFormatting.formattedDistance(from: distance, unit: distanceUnit))
                }
                if let burn = workout.activeEnergyKilocalories {
                    receiptMetric("Burn", ActivityFormatting.formattedCalories(burn))
                }
                if let steps = workout.steps {
                    receiptMetric("Steps", steps.formatted())
                }
            }

            Text(workout.startDate, format: .dateTime.weekday(.wide).month(.wide).day().hour().minute())
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.stepMuted)
                .lineLimit(2)
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [style.accent.opacity(0.16), Color.stepSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(style.accent.opacity(0.18), lineWidth: 1)
        )
    }

    private func receiptMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundStyle(Color.stepInk)
                .lineLimit(1)
                .minimumScaleFactor(0.70)
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.stepMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WorkoutVisualStyle {
    let accent: Color
    let icon: String

    init(kind: ActivityKind) {
        icon = StepReceiptSymbol.workoutIcon(for: kind)
        accent = switch kind {
        case .walking, .hiking:
            Color.stepAccent
        case .running:
            Color(red: 0.900, green: 0.240, blue: 0.240)
        case .cycling, .rowing, .swimming:
            Color.stepDistance
        case .strengthTraining:
            Color.stepEnergy
        case .elliptical, .stairClimbing:
            Color(red: 0.640, green: 0.430, blue: 1.000)
        case .yoga:
            Color(red: 0.300, green: 0.700, blue: 0.430)
        case .other:
            Color.stepAccent
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
