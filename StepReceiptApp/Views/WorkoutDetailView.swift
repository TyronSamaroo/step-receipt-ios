import Charts
import MapKit
import SwiftUI

struct WorkoutDetailView: View {
    @EnvironmentObject private var repository: ActivityRepository
    let workout: WorkoutActivity
    @State private var shareImage: ShareImage?
    @State private var tagDraft = ""

    private var style: WorkoutVisualStyle {
        WorkoutVisualStyle(kind: workout.type)
    }

    private var workoutTag: String? {
        repository.workoutTag(for: workout)
    }

    private var selectedTemplate: WorkoutTemplate? {
        WorkoutTemplate.preferred(for: workout, tag: workoutTag)
    }

    private var templateSuggestions: [WorkoutTemplate] {
        let primary = WorkoutTemplate.suggestions(for: workout)
        guard !primary.isEmpty else {
            return Array(WorkoutTemplate.allCases)
        }
        let remaining = WorkoutTemplate.allCases.filter { !primary.contains($0) }
        return primary + remaining
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                WorkoutHero(workout: workout, style: style, tag: workoutTag)
                templatePanel
                metricGrid
                sameTypeContextPanel
                HeartRatePanel(workout: workout)
                WorkoutRoutePanel(workout: workout, style: style)
                insightPanel
                detailPanel
                WorkoutShareCard(workout: workout, distanceUnit: repository.preferences.distanceUnit, tag: workoutTag)
            }
            .padding(16)
        }
        .safeAreaPadding(.bottom, 84)
        .background(Color.stepBackground)
        .navigationTitle(workoutTag ?? workout.displayTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    shareImage = ShareImageRenderer.render {
                        WorkoutShareCard(
                            workout: workout,
                            distanceUnit: repository.preferences.distanceUnit,
                            tag: workoutTag
                        )
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
        .onAppear {
            tagDraft = workoutTag ?? ""
        }
        .onChange(of: workoutTag) { _, newValue in
            tagDraft = newValue ?? ""
        }
    }

    private var metricGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
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
            } else {
                WorkoutMetricTile(
                    title: "Distance",
                    value: ActivityFormatting.formattedDistance(from: 0, unit: repository.preferences.distanceUnit),
                    icon: StepReceiptSymbol.distance,
                    color: Color.stepDistance
                )
            }

            if let burn = workout.activeEnergyKilocalories {
                WorkoutMetricTile(
                    title: "Active Energy",
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

            WorkoutMetricTile(
                title: "Effort",
                value: effortText,
                icon: "bolt.heart",
                color: effortColor
            )

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

    @ViewBuilder
    private var sameTypeContextPanel: some View {
        if !sameTypeRecentWorkouts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Label("Same Type Context", systemImage: "chart.bar.doc.horizontal")
                        .font(.headline)
                        .foregroundStyle(Color.stepInk)
                    Spacer(minLength: 0)
                    Text("Last 30 days")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(style.accent)
                        .lineLimit(1)
                }

                Text(sameTypeContextSummary)
                    .font(.subheadline)
                    .foregroundStyle(Color.stepMuted)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    insightRow(
                        "Recent",
                        "\(sameTypeRecentWorkouts.count.formatted()) in 30 days",
                        "calendar.badge.clock",
                        style.accent
                    )

                    if let sameTypeAverageDuration {
                        insightRow(
                            "Avg duration",
                            ActivityFormatting.formattedMinutes(sameTypeAverageDuration),
                            "clock",
                            style.accent
                        )
                    }

                    insightRow(
                        "Avg active",
                        sameTypeAverageActiveCalories.map(ActivityFormatting.formattedCalories) ?? "No calorie data",
                        StepReceiptSymbol.activeEnergy,
                        Color.stepEnergy
                    )

                    insightRow(
                        "Compared",
                        sameTypeComparisonText,
                        "arrow.left.arrow.right",
                        sameTypeComparisonColor
                    )
                }
            }
            .metricCard()
        }
    }

    private var templatePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label("Workout Template", systemImage: "square.grid.2x2")
                    .font(.headline)
                    .foregroundStyle(Color.stepInk)
                Spacer(minLength: 0)
                if let selectedTemplate {
                    Text(selectedTemplate.displayName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(style.accent)
                        .lineLimit(1)
                } else if let workoutTag {
                    Text(workoutTag)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.stepMuted)
                        .lineLimit(1)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(templateSuggestions) { template in
                        FilterChip(
                            title: template.displayName,
                            isSelected: workoutTag == template.displayName
                        ) {
                            tagDraft = template.displayName
                            repository.updateWorkoutTag(template.displayName, for: workout)
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            if let selectedTemplate {
                Label(selectedTemplate.shortDescription, systemImage: templateIcon(for: selectedTemplate))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.stepMuted)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                TextField("Custom tag", text: $tagDraft)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.stepBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.stepAxisGrid, lineWidth: 1)
                    )

                Button("Save") {
                    repository.updateWorkoutTag(tagDraft, for: workout)
                    tagDraft = workoutTag ?? ""
                }
                .buttonStyle(.borderedProminent)
                .tint(style.accent)

                Button {
                    tagDraft = ""
                    repository.updateWorkoutTag(nil, for: workout)
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.bordered)
                .tint(Color.stepMuted)
                .accessibilityLabel("Clear workout tag")
            }

            Text("Templates stay on this device as workout tags and are not synced.")
                .font(.caption)
                .foregroundStyle(Color.stepMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .metricCard()
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

    private var sameTypeRecentWorkouts: [WorkoutActivity] {
        let calendar = Calendar.current
        let selectedDayStart = calendar.startOfDay(for: workout.startDate)
        let windowStart = calendar.date(byAdding: .day, value: -29, to: selectedDayStart) ?? selectedDayStart
        let windowEnd = calendar.date(byAdding: .day, value: 1, to: selectedDayStart) ?? workout.endDate

        return repository.workouts
            .filter { candidate in
                candidate.type == workout.type
                    && candidate.startDate >= windowStart
                    && candidate.startDate < windowEnd
            }
            .sorted { $0.startDate > $1.startDate }
    }

    private var sameTypePeerWorkouts: [WorkoutActivity] {
        sameTypeRecentWorkouts.filter { $0.sourceIdentifier != workout.sourceIdentifier }
    }

    private var sameTypeAverageDuration: Double? {
        average(sameTypeRecentWorkouts.map(\.durationMinutes))
    }

    private var sameTypeAverageActiveCalories: Double? {
        average(sameTypeRecentWorkouts.compactMap(\.activeEnergyKilocalories))
    }

    private var sameTypePeerAverageDuration: Double? {
        average(sameTypePeerWorkouts.map(\.durationMinutes))
    }

    private var sameTypePeerAverageActiveCalories: Double? {
        average(sameTypePeerWorkouts.compactMap(\.activeEnergyKilocalories))
    }

    private var sameTypeDurationDelta: Double? {
        guard let sameTypePeerAverageDuration else { return nil }
        return workout.durationMinutes - sameTypePeerAverageDuration
    }

    private var sameTypeActiveCaloriesDelta: Double? {
        guard let burn = workout.activeEnergyKilocalories,
              let sameTypePeerAverageActiveCalories else { return nil }
        return burn - sameTypePeerAverageActiveCalories
    }

    private var sameTypeContextSummary: String {
        let workoutName = workout.displayTitle.lowercased()
        let countText = "\(sameTypeRecentWorkouts.count.formatted()) \(workoutName) \(sameTypeRecentWorkouts.count == 1 ? "workout" : "workouts") in this 30-day window."
        guard !sameTypePeerWorkouts.isEmpty else {
            return "\(countText) More same-type workouts will unlock a cleaner comparison."
        }

        return "\(countText) \(sameTypeComparisonText) versus recent peers."
    }

    private var sameTypeComparisonText: String {
        if let sameTypeActiveCaloriesDelta, abs(sameTypeActiveCaloriesDelta) >= 10 {
            return "\(formattedSignedCalories(sameTypeActiveCaloriesDelta)) active burn"
        }

        if let sameTypeDurationDelta, abs(sameTypeDurationDelta) >= 1 {
            return "\(formattedSignedMinutes(sameTypeDurationDelta)) duration"
        }

        return sameTypePeerWorkouts.isEmpty ? "No peer average yet" : "Near average"
    }

    private var sameTypeComparisonColor: Color {
        if let sameTypeActiveCaloriesDelta, abs(sameTypeActiveCaloriesDelta) >= 10 {
            return sameTypeActiveCaloriesDelta >= 0 ? Color.stepEnergy : Color.stepMuted
        }

        if let sameTypeDurationDelta, abs(sameTypeDurationDelta) >= 1 {
            return sameTypeDurationDelta >= 0 ? style.accent : Color.stepMuted
        }

        return style.accent
    }

    private var primaryInsight: String {
        if let averageHeartRate = workout.averageHeartRateBPM {
            return "\(workout.displayTitle) averaged \(Int(averageHeartRate.rounded())) bpm with \(effortText.lowercased()) effort."
        }

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

    private var effortText: String {
        WorkoutEffort(workout: workout).title
    }

    private var effortColor: Color {
        WorkoutEffort(workout: workout).color
    }

    private var weatherText: String? {
        let temperature = workout.weatherTemperatureCelsius.map { "\(Int(celsiusToFahrenheit($0).rounded())) F" }
        let humidity = workout.weatherHumidityPercent.map { "\(Int($0.rounded()))%" }
        return [temperature, humidity].compactMap { $0 }.joined(separator: "  ").nilIfEmpty
    }

    private func celsiusToFahrenheit(_ celsius: Double) -> Double {
        celsius * 9 / 5 + 32
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

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func formattedSignedMinutes(_ minutes: Double) -> String {
        let roundedMinutes = Int(minutes.rounded())
        if roundedMinutes == 0 {
            return "0 min"
        }

        return "\(roundedMinutes > 0 ? "+" : "-")\(abs(roundedMinutes)) min"
    }

    private func formattedSignedCalories(_ calories: Double) -> String {
        let roundedCalories = Int(calories.rounded())
        if roundedCalories == 0 {
            return "0 kcal"
        }

        return "\(roundedCalories > 0 ? "+" : "-")\(abs(roundedCalories)) kcal"
    }

    private func templateIcon(for template: WorkoutTemplate) -> String {
        switch template {
        case .pushDay, .pullDay, .legDay:
            "dumbbell"
        case .stairSession:
            StepReceiptSymbol.stairClimbing
        case .outdoorWalk:
            "sun.max"
        case .indoorWalk:
            "house"
        }
    }
}

struct HeartRatePanel: View {
    let workout: WorkoutActivity

    private var zones: [HeartRateZoneBreakdown] {
        HeartRateZoneBreakdown.zones(for: workout)
    }

    private var totalTrackedSeconds: TimeInterval {
        zones.reduce(0) { $0 + $1.durationSeconds }
    }

    private var segments: [HeartRateZoneSegment] {
        HeartRateZoneSegment.segments(for: workout)
    }

    private var chartDomain: ClosedRange<Double> {
        let maxValue = max(150, ((workout.maxHeartRateBPM ?? 150) / 25).rounded(.up) * 25)
        return 0...maxValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Heart Rate", systemImage: "heart.fill")
                .font(.headline)
                .foregroundStyle(Color(red: 1.0, green: 0.28, blue: 0.30))

            if workout.heartRateSamples.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No heart-rate samples for this workout.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.stepInk)
                    Text("Reconnect Apple Health in Settings if heart-rate permission was added after your first install.")
                        .font(.footnote)
                        .foregroundStyle(Color.stepMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            } else {
                HStack(spacing: 44) {
                    heartRateStat("Average", workout.averageHeartRateBPM)
                    heartRateStat("Max", workout.maxHeartRateBPM)
                }

                heartRateChart
                zoneTimeline
                zoneRows
            }
        }
        .metricCard()
    }

    private var heartRateChart: some View {
        Chart(workout.heartRateSamples) { sample in
            LineMark(
                x: .value("Time", sample.timestamp),
                y: .value("Heart Rate", sample.beatsPerMinute)
            )
            .interpolationMethod(.catmullRom)
            .lineStyle(.init(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .foregroundStyle(Color(red: 1.0, green: 0.28, blue: 0.30))
        }
        .frame(height: 220)
        .chartXScale(domain: workout.startDate...workout.endDate)
        .chartYScale(domain: chartDomain)
        .chartXAxis {
            AxisMarks(values: .stride(by: .minute, count: 15)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .foregroundStyle(Color.stepAxisGrid)
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.hour().minute())
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.stepAxis)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .stride(by: 50)) {
                AxisGridLine()
                    .foregroundStyle(Color.stepAxisGrid)
                AxisValueLabel()
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.stepAxis)
            }
        }
    }

    private var zoneTimeline: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    Rectangle()
                        .fill(segment.zone.color.opacity(0.78))
                        .frame(width: max(1, proxy.size.width * segment.durationSeconds / max(1, totalTrackedSeconds)))
                }
            }
        }
        .frame(height: 10)
        .background(Color.stepAxisGrid)
        .clipShape(Capsule())
    }

    private var zoneRows: some View {
        VStack(spacing: 12) {
            ForEach(zones) { zone in
                HStack(spacing: 10) {
                    Text(zone.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(zone.color)
                        .frame(width: 62, alignment: .leading)

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(zone.color.opacity(0.12))
                            Capsule()
                                .fill(zone.color.opacity(0.75))
                                .frame(width: proxy.size.width * zone.durationSeconds / max(1, totalTrackedSeconds))
                        }
                    }
                    .frame(height: 10)

                    Text(ActivityFormatting.formattedDuration(zone.durationSeconds))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Color.stepMuted)
                        .frame(width: 74, alignment: .trailing)

                    Text(zone.rangeLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.stepMuted)
                        .frame(width: 78, alignment: .trailing)
                }
            }
        }
    }

    private func heartRateStat(_ title: String, _ value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.stepMuted)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value.map { Int($0.rounded()).formatted() } ?? "--")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.stepInk)
                    .monospacedDigit()
                Text("bpm")
                    .font(.headline)
                    .foregroundStyle(Color.stepMuted)
            }
        }
    }
}

struct WorkoutRoutePanel: View {
    let workout: WorkoutActivity
    let style: WorkoutVisualStyle
    @State private var cameraPosition: MapCameraPosition

    init(workout: WorkoutActivity, style: WorkoutVisualStyle) {
        self.workout = workout
        self.style = style
        _cameraPosition = State(initialValue: .rect(workout.routeMapRect ?? .world))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Route Map", systemImage: "map")
                .font(.headline)
                .foregroundStyle(Color.stepInk)

            if workout.hasRoute {
                Map(position: $cameraPosition, interactionModes: []) {
                    MapPolyline(coordinates: workout.routeCoordinates)
                        .stroke(style.accent, lineWidth: 4)
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.stepAxisGrid, lineWidth: 1)
                )
                .accessibilityLabel("Outdoor workout route map")

                Text("\(workout.routePoints.count.formatted()) route points stay on this iPhone and are not included in share cards or sync.")
                    .font(.caption)
                    .foregroundStyle(Color.stepMuted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(unavailableTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.stepInk)
                    Text(unavailableMessage)
                        .font(.footnote)
                        .foregroundStyle(Color.stepMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            }
        }
        .metricCard()
        .onChange(of: workout.routePoints) { _, _ in
            cameraPosition = .rect(workout.routeMapRect ?? .world)
        }
    }

    private var unavailableTitle: String {
        workout.environment == .indoor ? "No outdoor route for this workout." : "Route unavailable."
    }

    private var unavailableMessage: String {
        if workout.environment == .indoor {
            return "Indoor workouts do not include Health route maps."
        }

        return "Apple Health did not provide route points, or route permission is limited. Route data stays on-device when available."
    }
}

private extension WorkoutActivity {
    var routeCoordinates: [CLLocationCoordinate2D] {
        routePoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    var routeMapRect: MKMapRect? {
        guard let first = routeCoordinates.first else { return nil }
        var rect = MKMapRect(origin: MKMapPoint(first), size: MKMapSize(width: 1, height: 1))

        for coordinate in routeCoordinates.dropFirst() {
            let point = MKMapPoint(coordinate)
            rect = rect.union(MKMapRect(origin: point, size: MKMapSize(width: 1, height: 1)))
        }

        let padding = max(rect.width, rect.height) * 0.18
        return rect.insetBy(dx: -max(padding, 80), dy: -max(padding, 80))
    }
}

struct WorkoutHero: View {
    let workout: WorkoutActivity
    let style: WorkoutVisualStyle
    let tag: String?

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
                    Text(tag ?? workout.displayTitle)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.stepInk)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                    if tag != nil {
                        Text(workout.displayTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(style.accent)
                            .lineLimit(1)
                    }
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
        if let weatherChipText {
            heroChip(weatherChipText, systemImage: "cloud.sun")
        }
        heroChip(workout.sourceName, systemImage: StepReceiptSymbol.healthCard)
    }

    private var weatherChipText: String? {
        let temperature = workout.weatherTemperatureCelsius.map { "\(Int(celsiusToFahrenheit($0).rounded())) F" }
        let humidity = workout.weatherHumidityPercent.map { "\(Int($0.rounded()))%" }
        return [temperature, humidity].compactMap { $0 }.joined(separator: "  ").nilIfEmpty
    }

    private func celsiusToFahrenheit(_ celsius: Double) -> Double {
        celsius * 9 / 5 + 32
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
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
                    .frame(width: 20, height: 20)
                    .background(color.opacity(0.14))
                    .clipShape(Circle())

                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.stepMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.stepInk)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .frame(minHeight: 72, alignment: .topLeading)
        .background(Color.stepSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
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

struct WorkoutEffort {
    let title: String
    let color: Color

    init(workout: WorkoutActivity) {
        if let averageHeartRate = workout.averageHeartRateBPM {
            let zone = HeartRateZoneBreakdown.template(for: averageHeartRate)
            title = switch zone.level {
            case 1: "Easy"
            case 2: "Steady"
            case 3: "Hard"
            default: "Peak"
            }
            color = zone.color
            return
        }

        if let burn = workout.activeEnergyKilocalories, workout.durationMinutes > 0 {
            let burnRate = burn / workout.durationMinutes
            switch burnRate {
            case ..<4:
                title = "Easy"
                color = HeartRateZoneBreakdown.zone1Color
            case ..<7:
                title = "Steady"
                color = HeartRateZoneBreakdown.zone2Color
            case ..<10:
                title = "Hard"
                color = HeartRateZoneBreakdown.zone4Color
            default:
                title = "Peak"
                color = HeartRateZoneBreakdown.zone5Color
            }
            return
        }

        title = "Logged"
        color = Color.stepAccent
    }
}

struct HeartRateZoneBreakdown: Identifiable {
    let level: Int
    let title: String
    let lowerBound: Double?
    let upperBound: Double?
    let durationSeconds: TimeInterval
    let color: Color

    var id: Int { level }

    var rangeLabel: String {
        switch (lowerBound, upperBound) {
        case (nil, let upper?):
            "< \(Int(upper.rounded())) bpm"
        case (let lower?, let upper?):
            "\(Int(lower.rounded()))-\(Int(upper.rounded())) bpm"
        case (let lower?, nil):
            ">= \(Int(lower.rounded())) bpm"
        default:
            "bpm"
        }
    }

    static let zone1Color = Color(red: 0.82, green: 0.84, blue: 0.88)
    static let zone2Color = Color(red: 0.54, green: 0.88, blue: 0.96)
    static let zone3Color = Color(red: 0.32, green: 0.82, blue: 0.62)
    static let zone4Color = Color(red: 1.00, green: 0.55, blue: 0.22)
    static let zone5Color = Color(red: 1.00, green: 0.24, blue: 0.38)

    private static let estimatedMaxHeartRate = 191.0

    private static var thresholds: [Double] {
        [
            estimatedMaxHeartRate * 0.60,
            estimatedMaxHeartRate * 0.70,
            estimatedMaxHeartRate * 0.80,
            estimatedMaxHeartRate * 0.90
        ]
    }

    static func zones(for workout: WorkoutActivity) -> [HeartRateZoneBreakdown] {
        let segments = HeartRateZoneSegment.segments(for: workout)
        return (1...5).map { level in
            let template = template(forLevel: level)
            return HeartRateZoneBreakdown(
                level: template.level,
                title: template.title,
                lowerBound: template.lowerBound,
                upperBound: template.upperBound,
                durationSeconds: segments
                    .filter { $0.zone.level == level }
                    .reduce(0) { $0 + $1.durationSeconds },
                color: template.color
            )
        }
    }

    static func template(for beatsPerMinute: Double) -> HeartRateZoneBreakdown {
        let zoneLevel: Int
        switch beatsPerMinute {
        case ..<thresholds[0]:
            zoneLevel = 1
        case ..<thresholds[1]:
            zoneLevel = 2
        case ..<thresholds[2]:
            zoneLevel = 3
        case ..<thresholds[3]:
            zoneLevel = 4
        default:
            zoneLevel = 5
        }
        return template(forLevel: zoneLevel)
    }

    private static func template(forLevel level: Int) -> HeartRateZoneBreakdown {
        switch level {
        case 1:
            HeartRateZoneBreakdown(level: 1, title: "Zone 1", lowerBound: nil, upperBound: thresholds[0], durationSeconds: 0, color: zone1Color)
        case 2:
            HeartRateZoneBreakdown(level: 2, title: "Zone 2", lowerBound: thresholds[0], upperBound: thresholds[1], durationSeconds: 0, color: zone2Color)
        case 3:
            HeartRateZoneBreakdown(level: 3, title: "Zone 3", lowerBound: thresholds[1], upperBound: thresholds[2], durationSeconds: 0, color: zone3Color)
        case 4:
            HeartRateZoneBreakdown(level: 4, title: "Zone 4", lowerBound: thresholds[2], upperBound: thresholds[3], durationSeconds: 0, color: zone4Color)
        default:
            HeartRateZoneBreakdown(level: 5, title: "Zone 5", lowerBound: thresholds[3], upperBound: nil, durationSeconds: 0, color: zone5Color)
        }
    }
}

struct HeartRateZoneSegment {
    let zone: HeartRateZoneBreakdown
    let durationSeconds: TimeInterval

    static func segments(for workout: WorkoutActivity) -> [HeartRateZoneSegment] {
        let samples = workout.heartRateSamples
        guard !samples.isEmpty else { return [] }

        let fallbackDuration = max(1, workout.durationMinutes * 60 / Double(samples.count))
        return samples.enumerated().map { index, sample in
            let nextDate = index + 1 < samples.count ? samples[index + 1].timestamp : workout.endDate
            var duration = nextDate.timeIntervalSince(sample.timestamp)
            if duration <= 0 || duration > fallbackDuration * 4 {
                duration = fallbackDuration
            }

            return HeartRateZoneSegment(
                zone: HeartRateZoneBreakdown.template(for: sample.beatsPerMinute),
                durationSeconds: max(1, duration)
            )
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
