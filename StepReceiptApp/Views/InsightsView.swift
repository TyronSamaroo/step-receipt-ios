import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var repository: ActivityRepository
    @State private var selectedScope: ActivityPeriodScope = .week
    @State private var shareImage: ShareImage?

    private var period: PeriodActivitySummary {
        repository.periodSummary(scope: selectedScope)
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

                    PeriodReceiptCard(period: period, distanceUnit: repository.preferences.distanceUnit)

                    PeriodHeatMap(period: period)

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
        let activeDays = period.summaries
            .filter(\.hasActivityData)
            .sorted {
                if $0.steps == $1.steps {
                    return $0.dateStart > $1.dateStart
                }
                return $0.steps > $1.steps
            }
            .prefix(5)

        if !activeDays.isEmpty {
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
                    ForEach(Array(activeDays), id: \.id) { summary in
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
                        }
                        .padding(12)
                        .background(Color.stepBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
            .metricCard()
        }
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
