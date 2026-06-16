import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var repository: ActivityRepository
    @State private var selectedScope: ActivityPeriodScope = .week
    @State private var periodAnchorDate = Date()
    @State private var shareImage: ShareImage?

    private var period: PeriodActivitySummary {
        repository.periodSummary(scope: selectedScope, containing: periodAnchorDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Period", selection: $selectedScope) {
                        ForEach(ActivityPeriodScope.allCases) { scope in
                            Text(scope.displayName).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)

                    periodNavigator

                    PeriodReceiptCard(period: period, distanceUnit: repository.preferences.distanceUnit)

                    PeriodHeatMap(period: period)

                    NavigationLink {
                        CardioDetailView(scope: selectedScope, anchorDate: periodAnchorDate)
                    } label: {
                        CardioInsightCard(insight: period.cardioInsight, distanceUnit: repository.preferences.distanceUnit)
                    }
                    .buttonStyle(.plain)

                    periodStats

                    if selectedScope != .day {
                        bestDays
                    }
                }
                .padding(16)
            }
            .safeAreaPadding(.bottom, 84)
            .background(Color.stepBackground)
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: clampPeriodAnchor)
            .onChange(of: selectedScope) { _, _ in
                clampPeriodAnchor()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        shareImage = ShareImageRenderer.render {
                            PeriodReceiptCard(period: period, distanceUnit: repository.preferences.distanceUnit)
                                .frame(width: 390)
                                .padding(18)
                                .background(Color.stepBackground)
                        }
                    } label: {
                        Image(systemName: StepReceiptSymbol.share)
                    }
                    .accessibilityLabel("Share receipt")
                    .disabled(period.summaries.isEmpty)
                }
            }
        }
        .sheet(item: $shareImage) { shareImage in
            ShareSheet(items: [shareImage.image])
        }
    }

    private var periodNavigator: some View {
        HStack(spacing: 14) {
            periodButton(systemImage: "chevron.left", label: "Previous period", offset: -1)

            VStack(spacing: 2) {
                Text(periodLabel)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.stepInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .accessibilityIdentifier("insights-period-label")

                Text(periodSubtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.stepMuted)
            }
            .frame(maxWidth: .infinity)

            periodButton(systemImage: "chevron.right", label: "Next period", offset: 1)
        }
        .padding(12)
        .background(Color.stepSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func periodButton(systemImage: String, label: String, offset: Int) -> some View {
        let anchor = repository.adjacentInsightPeriodAnchor(
            scope: selectedScope,
            containing: periodAnchorDate,
            offset: offset
        )

        return Button {
            if let anchor {
                periodAnchorDate = anchor
            }
        } label: {
            Image(systemName: systemImage)
                .font(.title3.weight(.bold))
                .foregroundStyle(anchor == nil ? Color.stepMuted.opacity(0.45) : Color.stepAccent)
                .frame(width: 46, height: 46)
                .background(anchor == nil ? Color.stepBackground.opacity(0.7) : Color.stepAccent.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(anchor == nil)
        .accessibilityLabel(label)
    }

    private var periodLabel: String {
        switch selectedScope {
        case .day:
            period.periodStart.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
        case .week:
            "\(period.periodStart.formatted(.dateTime.month(.abbreviated).day())) - \(period.periodEnd.addingTimeInterval(-1).formatted(.dateTime.month(.abbreviated).day()))"
        case .month:
            period.periodStart.formatted(.dateTime.month(.wide).year())
        }
    }

    private var periodSubtitle: String {
        switch selectedScope {
        case .day:
            "Daily receipt"
        case .week:
            "Monday start"
        case .month:
            "\(period.activeDays) active days"
        }
    }

    private func clampPeriodAnchor() {
        guard let anchor = repository.adjacentInsightPeriodAnchor(
            scope: selectedScope,
            containing: periodAnchorDate,
            offset: 0
        ) else {
            return
        }
        periodAnchorDate = anchor
    }

    private var periodStats: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricTile(title: "Daily Avg", value: "\(period.receipt.dailyAverageSteps.formatted())", icon: "calendar")
            MetricTile(title: "Goal Days", value: "\(period.goalHitDays)/\(max(1, period.summaries.count))", icon: "target")
            MetricTile(title: "Workouts", value: period.workoutCount.formatted(), icon: StepReceiptSymbol.workout)
            MetricTile(title: "Streak", value: "\(period.receipt.currentStepGoalStreakDays)d", icon: StepReceiptSymbol.activeEnergy)
        }
    }

    @ViewBuilder
    private var bestDays: some View {
        let displayDays = selectedScope == .week
            ? period.summaries.sorted { $0.dateStart < $1.dateStart }
            : Array(
                period.summaries
                    .filter(\.hasActivityData)
                    .sorted {
                        if $0.steps == $1.steps {
                            return $0.dateStart > $1.dateStart
                        }
                        return $0.steps > $1.steps
                    }
                    .prefix(5)
            )

        if !displayDays.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(selectedScope == .week ? "Week Detail" : "Top Days")
                        .font(.headline)
                        .foregroundStyle(Color.stepInk)
                    Spacer()
                    Text("\(period.activeDays) active")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.stepMuted)
                }

                VStack(spacing: 10) {
                    ForEach(displayDays, id: \.id) { summary in
                        NavigationLink {
                            DaySummaryDetailView(summary: summary)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(summary.dateStart, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color.stepInk)
                                    Text("\(summary.workouts.count) workouts · \(ActivityFormatting.formattedMinutes(summary.workoutMinutes))")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.stepMuted)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(summary.steps.formatted())
                                        .font(.headline.monospacedDigit().weight(.bold))
                                        .foregroundStyle(Color.stepInk)
                                    Text(summary.steps >= summary.goals.stepsPerDay ? "Goal hit" : "Open")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(summary.steps >= summary.goals.stepsPerDay ? Color.stepAccent : Color.stepMuted)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.stepMuted)
                            }
                            .padding(12)
                            .background(Color.stepBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(summary.dateStart.formatted(date: .abbreviated, time: .omitted)), \(summary.workouts.count) workouts, \(summary.steps.formatted()) steps")
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("insights-week-day-row-\(summary.id)")
                    }
                }
            }
            .metricCard()
        }
    }
}

private struct CardioInsightCard: View {
    let insight: CardioPeriodInsight
    let distanceUnit: DistanceUnit

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Cardio", systemImage: "figure.run")
                    .font(.headline)
                    .foregroundStyle(Color.stepInk)
                Spacer()
                Text(insight.hasCardio ? "\(insight.sessionCount) sessions" : "No sessions")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.stepMuted)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.stepMuted)
            }

            if insight.hasCardio {
                LazyVGrid(columns: columns, spacing: 10) {
                    cardioStat("Minutes", ActivityFormatting.formattedMinutes(insight.totalMinutes), Color.stepAccent)
                    cardioStat("Distance", ActivityFormatting.formattedDistance(from: insight.totalDistanceMeters, unit: distanceUnit), Color.stepDistance)
                    cardioStat("Burn", ActivityFormatting.formattedCalories(insight.totalActiveEnergyKilocalories), Color.stepEnergy)
                    cardioStat("Avg HR", averageHeartRateText, Color.stepWarning)
                }

                if let workout = insight.bestWorkout {
                    Divider()
                    HStack(spacing: 12) {
                        Image(systemName: StepReceiptSymbol.workoutIcon(for: workout.type))
                            .font(.headline)
                            .foregroundStyle(Color.stepAccent)
                            .frame(width: 36, height: 36)
                            .background(Color.stepAccent.opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Best cardio")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.stepMuted)
                            Text(workout.displayTitle)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.stepInk)
                                .lineLimit(1)
                            Text(workout.startDate, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                                .font(.caption)
                                .foregroundStyle(Color.stepMuted)
                        }

                        Spacer()

                        Text(ActivityFormatting.formattedMinutes(workout.durationMinutes))
                            .font(.subheadline.monospacedDigit().weight(.bold))
                            .foregroundStyle(Color.stepInk)
                    }
                }
            } else {
                Text("No cardio workouts in this period yet. Walks, runs, cycling, stairs, hiking, swimming, elliptical, and rowing will show here.")
                    .font(.subheadline)
                    .foregroundStyle(Color.stepMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 74, alignment: .center)
            }
        }
        .metricCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("insights-cardio-card")
    }

    private var averageHeartRateText: String {
        guard let bpm = insight.averageHeartRateBPM else { return "--" }
        return "\(Int(bpm.rounded())) bpm"
    }

    private func cardioStat(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.stepInk)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.stepMuted)
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct CardioDetailView: View {
    @EnvironmentObject private var repository: ActivityRepository
    let scope: ActivityPeriodScope
    let anchorDate: Date
    @State private var isEditingZones = false

    private var period: PeriodActivitySummary {
        repository.periodSummary(scope: scope, containing: anchorDate)
    }

    private var insight: CardioPeriodInsight {
        period.cardioInsight
    }

    private var cardioWorkouts: [WorkoutActivity] {
        var workoutsBySource: [String: WorkoutActivity] = [:]
        for workout in period.summaries.flatMap(\.workouts) where workout.type.isCardioMovement {
            workoutsBySource[workout.sourceIdentifier] = workout
        }
        return workoutsBySource.values.sorted { $0.startDate > $1.startDate }
    }

    private var periodTitle: String {
        switch scope {
        case .day:
            period.periodStart.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
        case .week:
            "\(period.periodStart.formatted(.dateTime.month(.abbreviated).day())) - \(period.periodEnd.addingTimeInterval(-1).formatted(.dateTime.month(.abbreviated).day()))"
        case .month:
            period.periodStart.formatted(.dateTime.month(.wide).year())
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if insight.hasCardio {
                    statsGrid
                    zoneSection
                    bestWorkoutSection
                    workoutList
                } else {
                    ContentUnavailableView(
                        "No cardio in this period",
                        systemImage: "figure.run",
                        description: Text("Walks, runs, cycling, stairs, hiking, swimming, elliptical, and rowing will show here.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 260)
                    .metricCard()
                }
            }
            .padding(16)
            .accessibilityIdentifier("cardio-detail-screen")
        }
        .safeAreaPadding(.bottom, 84)
        .background(Color.stepBackground)
        .navigationTitle("Cardio Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isEditingZones = true
                } label: {
                    Label("Edit Zones", systemImage: "slider.horizontal.3")
                }
                .accessibilityIdentifier("edit-heart-rate-zones-button")
            }
        }
        .sheet(isPresented: $isEditingZones) {
            HeartRateZoneEditorView()
                .environmentObject(repository)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "figure.run")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.stepDistance)
                    .frame(width: 48, height: 48)
                    .background(Color.stepDistance.opacity(0.14))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(periodTitle)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.stepInk)
                    Text("\(insight.sessionCount) sessions · \(ActivityFormatting.formattedMinutes(insight.totalMinutes))")
                        .font(.headline)
                        .foregroundStyle(Color.stepMuted)
                }
                Spacer(minLength: 0)
            }

            Text("Heart-rate zones use your editable defaults and apply across cardio, workout details, and share cards.")
                .font(.subheadline)
                .foregroundStyle(Color.stepMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .metricCard()
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricTile(title: "Minutes", value: ActivityFormatting.formattedMinutes(insight.totalMinutes), icon: StepReceiptSymbol.workout)
            MetricTile(title: "Distance", value: ActivityFormatting.formattedDistance(from: insight.totalDistanceMeters, unit: repository.preferences.distanceUnit), icon: StepReceiptSymbol.distance)
            MetricTile(title: "Active Burn", value: ActivityFormatting.formattedCalories(insight.totalActiveEnergyKilocalories), icon: StepReceiptSymbol.activeEnergy)
            MetricTile(title: "Avg HR", value: averageHeartRateText, icon: "heart.fill")
        }
    }

    private var zoneSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Zone Time", systemImage: "heart.fill")
                    .font(.headline)
                    .foregroundStyle(Color.stepInk)
                Spacer()
                Text(ActivityFormatting.formattedDuration(insight.totalZoneSeconds))
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(Color.stepMuted)
            }

            if insight.totalZoneSeconds > 0 {
                zoneStackedBar
                VStack(spacing: 12) {
                    ForEach(insight.zoneSummaries) { zone in
                        HeartRateZoneRow(zone: zone, totalSeconds: insight.totalZoneSeconds)
                            .accessibilityIdentifier("heart-rate-zone-row-\(zone.level)")
                    }
                }
            } else {
                Text("No heart-rate samples for these cardio sessions.")
                    .font(.subheadline)
                    .foregroundStyle(Color.stepMuted)
                    .frame(maxWidth: .infinity, minHeight: 70, alignment: .center)
            }
        }
        .metricCard()
    }

    private var zoneStackedBar: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                ForEach(insight.zoneSummaries) { zone in
                    Rectangle()
                        .fill(zone.color.opacity(zone.durationSeconds > 0 ? 0.82 : 0.16))
                        .frame(width: max(zone.durationSeconds > 0 ? 1 : 0, proxy.size.width * zone.durationSeconds / max(1, insight.totalZoneSeconds)))
                }
            }
        }
        .frame(height: 12)
        .background(Color.stepAxisGrid)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var bestWorkoutSection: some View {
        if let bestWorkout = insight.bestWorkout {
            NavigationLink {
                WorkoutDetailView(workout: bestWorkout)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: StepReceiptSymbol.workoutIcon(for: bestWorkout.type))
                        .font(.headline)
                        .foregroundStyle(Color.stepAccent)
                        .frame(width: 42, height: 42)
                        .background(Color.stepAccent.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Best cardio")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.stepMuted)
                        Text(repository.workoutTag(for: bestWorkout) ?? bestWorkout.displayTitle)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.stepInk)
                            .lineLimit(1)
                        Text(bestWorkout.startDate, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
                            .font(.caption)
                            .foregroundStyle(Color.stepMuted)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.stepMuted)
                }
                .metricCard()
            }
            .buttonStyle(.plain)
        }
    }

    private var workoutList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Cardio Workouts")
                    .font(.headline)
                    .foregroundStyle(Color.stepInk)
                Spacer()
                Text("\(cardioWorkouts.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.stepMuted)
            }

            ForEach(cardioWorkouts) { workout in
                NavigationLink {
                    WorkoutDetailView(workout: workout)
                } label: {
                    WorkoutRow(workout: workout, tag: repository.workoutTag(for: workout))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("cardio-detail-workout-row-\(workout.sourceIdentifier)")
            }
        }
        .metricCard()
    }

    private var averageHeartRateText: String {
        guard let bpm = insight.averageHeartRateBPM else { return "--" }
        return "\(Int(bpm.rounded())) bpm"
    }
}

private struct HeartRateZoneRow: View {
    let zone: HeartRateZoneSummary
    let totalSeconds: TimeInterval

    var body: some View {
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
                        .frame(width: proxy.size.width * zone.durationSeconds / max(1, totalSeconds))
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

private struct HeartRateZoneEditorView: View {
    @EnvironmentObject private var repository: ActivityRepository
    @Environment(\.dismiss) private var dismiss
    @State private var lowerBounds: [Int] = HeartRateZoneConfiguration.default.lowerBoundsBPM

    private var isValid: Bool {
        HeartRateZoneConfiguration.isValid(lowerBoundsBPM: lowerBounds)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(0..<lowerBounds.count, id: \.self) { index in
                        Stepper(value: binding(for: index), in: 30...240, step: 1) {
                            HStack {
                                Text("Zone \(index + 2) starts")
                                Spacer()
                                Text("\(lowerBounds[index]) bpm")
                                    .font(.body.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(HeartRateZoneStyle.color(forLevel: index + 2))
                            }
                        }
                        .accessibilityIdentifier("heart-rate-zone-cutoff-\(index + 1)")
                    }
                } header: {
                    Text("Lower Bounds")
                } footer: {
                    Text("Values must stay in ascending order. Zone 1 starts below the first value and Zone 5 starts at the last value.")
                }

                if !isValid {
                    Section {
                        Text("Keep each zone start lower than the next one.")
                            .foregroundStyle(Color.stepWarning)
                    }
                }

                Section {
                    Button("Reset Defaults") {
                        lowerBounds = HeartRateZoneConfiguration.default.lowerBoundsBPM
                    }
                    .accessibilityIdentifier("heart-rate-zones-reset-defaults-button")
                }
            }
            .accessibilityIdentifier("heart-rate-zones-screen")
            .navigationTitle("Heart Rate Zones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        repository.updatePreferences(
                            heartRateZoneConfiguration: HeartRateZoneConfiguration(lowerBoundsBPM: lowerBounds)
                        )
                        dismiss()
                    }
                    .disabled(!isValid)
                    .accessibilityIdentifier("heart-rate-zones-save-button")
                }
            }
            .onAppear {
                lowerBounds = repository.preferences.heartRateZoneConfiguration.lowerBoundsBPM
            }
        }
    }

    private func binding(for index: Int) -> Binding<Int> {
        Binding(
            get: { lowerBounds[index] },
            set: { newValue in
                lowerBounds[index] = newValue
            }
        )
    }
}

struct PeriodReceiptCard: View {
    let period: PeriodActivitySummary
    let distanceUnit: DistanceUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(period.scope.displayName.uppercased()) RECEIPT")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.stepAccent)
                    Text("\(period.receipt.totalSteps.formatted()) steps")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.stepInk)
                        .minimumScaleFactor(0.74)
                }
                Spacer()
                Image(systemName: StepReceiptSymbol.receipt)
                    .font(.system(size: 38))
                    .foregroundStyle(Color.stepAccent)
            }

            Text(period.headline)
                .font(.headline)
                .foregroundStyle(Color.stepInk)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(spacing: 10) {
                receiptLine("Distance", ActivityFormatting.formattedDistance(from: period.receipt.totalDistanceMeters, unit: distanceUnit))
                receiptLine("Active burn", ActivityFormatting.formattedCalories(period.receipt.totalActiveEnergyKilocalories))
                receiptLine("Workout time", ActivityFormatting.formattedMinutes(period.receipt.totalWorkoutMinutes))
                receiptLine("Goal days", "\(period.goalHitDays)/\(max(1, period.summaries.count))")
                if let bestDay = period.bestDay {
                    receiptLine("Best day", "\(bestDay.steps.formatted()) steps")
                }
            }

            Text(periodRangeText)
                .font(.footnote)
                .foregroundStyle(Color.stepMuted)
        }
        .padding(18)
        .background(Color.stepSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var periodRangeText: String {
        let displayEnd = period.periodEnd.addingTimeInterval(-1)
        return "\(period.periodStart.formatted(date: .abbreviated, time: .omitted)) - \(displayEnd.formatted(date: .abbreviated, time: .omitted))"
    }

    private func receiptLine(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
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

struct PeriodHeatMap: View {
    let period: PeriodActivitySummary

    private var columns: [GridItem] {
        let count = period.scope == .month ? 7 : max(1, period.summaries.count)
        return Array(repeating: GridItem(.flexible(), spacing: 6), count: count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(period.scope == .day ? "Daily Timeline" : "Activity Heat Map", systemImage: "square.grid.3x3")
                    .font(.headline)
                    .foregroundStyle(Color.stepInk)
                Spacer()
                Text(legendText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.stepMuted)
            }

            if period.scope == .day {
                dayTimeline
            } else if period.summaries.isEmpty {
                Text("No activity in this period yet.")
                    .font(.subheadline)
                    .foregroundStyle(Color.stepMuted)
                    .frame(maxWidth: .infinity, minHeight: 110, alignment: .center)
            } else {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(period.summaries) { summary in
                        PeriodHeatTile(summary: summary)
                    }
                }
            }
        }
        .metricCard()
    }

    private var legendText: String {
        switch period.scope {
        case .day: "by hour"
        case .week: "\(period.summaries.count) days"
        case .month: "\(period.summaries.count) days"
        }
    }

    @ViewBuilder
    private var dayTimeline: some View {
        if let summary = period.summaries.first, !summary.buckets.isEmpty {
            VStack(spacing: 7) {
                ForEach(summary.buckets) { bucket in
                    HStack(spacing: 10) {
                        Text(bucket.startDate, format: .dateTime.hour())
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.stepMuted)
                            .frame(width: 48, alignment: .leading)

                        GeometryReader { proxy in
                            Capsule()
                                .fill(Color.stepAccent.opacity(hourOpacity(bucket.steps, goal: summary.goals.stepsPerDay)))
                                .frame(width: max(4, proxy.size.width * min(1, Double(bucket.steps) / max(1, Double(summary.goals.stepsPerDay) / 8))))
                        }
                        .frame(height: 12)

                        Text(bucket.steps.formatted())
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(Color.stepInk)
                            .frame(width: 56, alignment: .trailing)
                    }
                }
            }
        } else {
            Text("No hourly samples for this day.")
                .font(.subheadline)
                .foregroundStyle(Color.stepMuted)
                .frame(maxWidth: .infinity, minHeight: 110, alignment: .center)
        }
    }

    private func hourOpacity(_ steps: Int, goal: Int) -> Double {
        0.18 + min(0.82, Double(steps) / max(1, Double(goal) / 5))
    }
}

private struct PeriodHeatTile: View {
    let summary: DailyActivitySummary

    private var progress: Double {
        min(1, Double(summary.steps) / Double(max(1, summary.goals.stepsPerDay)))
    }

    private var color: Color {
        if summary.steps >= summary.goals.stepsPerDay {
            return Color.stepAccent
        }
        if !summary.workouts.isEmpty || summary.workoutMinutes > 0 {
            return Color.stepDistance
        }
        if summary.hasActivityData {
            return Color.stepEnergy
        }
        return Color.stepAxisGrid
    }

    var body: some View {
        VStack(spacing: 5) {
            Text(summary.dateStart, format: .dateTime.day())
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.stepMuted)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color.opacity(summary.hasActivityData ? 0.22 + progress * 0.72 : 0.32))
                .overlay(alignment: .bottomTrailing) {
                    if !summary.workouts.isEmpty {
                        Circle()
                            .fill(Color.stepInk.opacity(0.75))
                            .frame(width: 5, height: 5)
                            .padding(4)
                    }
                }
                .aspectRatio(1, contentMode: .fit)

            Text(shortSteps)
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(Color.stepInk)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(summary.dateStart.formatted(date: .abbreviated, time: .omitted)), \(summary.steps.formatted()) steps")
    }

    private var shortSteps: String {
        if summary.steps >= 10_000 {
            return "\(summary.steps / 1_000)k"
        }
        return summary.steps.formatted()
    }
}
