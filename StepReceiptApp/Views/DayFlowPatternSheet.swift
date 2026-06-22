import Charts
import SwiftUI

private enum DayFlowPatternScope: String, CaseIterable, Identifiable {
    case week
    case month

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .week: "This Week"
        case .month: "This Month"
        }
    }

    var activityScope: ActivityPeriodScope {
        switch self {
        case .week: .week
        case .month: .month
        }
    }
}

struct DayFlowPatternSheet: View {
    @EnvironmentObject private var repository: ActivityRepository
    @Environment(\.dismiss) private var dismiss

    let date: Date

    @State private var selectedScope: DayFlowPatternScope = .week
    @State private var pattern: StepPattern?
    @State private var isLoading = true

    private var period: PeriodActivitySummary {
        repository.periodSummary(scope: selectedScope.activityScope, containing: date)
    }

    private var coachInsights: [WeekPatternCoachInsight] {
        guard let pattern else { return [] }
        return repository.weekPatternCoachInsights(pattern: pattern, containing: date)
    }

    private var maxDailySteps: Int {
        max(1, period.summaries.map(\.steps).max() ?? 1)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    scopePicker

                    if isLoading {
                        ProgressView("Loading step pattern…")
                            .frame(maxWidth: .infinity, minHeight: 180)
                    } else if let pattern {
                        summaryPills(for: pattern)
                        PeriodHeatMap(period: period)
                            .accessibilityIdentifier("day-flow-pattern-heatmap")
                        hourProfileCard(for: pattern)
                        dailyBreakdownCard
                        coachBlock
                    } else {
                        ContentUnavailableView(
                            "No Pattern Yet",
                            systemImage: "chart.xyaxis.line",
                            description: Text("Hourly samples are not available for this period.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 180)
                    }
                }
                .padding(16)
            }
            .background(Color.stepBackground)
            .navigationTitle("Step Pattern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .accessibilityIdentifier("day-flow-pattern-sheet")
            .task(id: selectedScope) {
                await loadPattern()
            }
        }
    }

    private var scopePicker: some View {
        Picker("Period", selection: $selectedScope) {
            ForEach(DayFlowPatternScope.allCases) { scope in
                Text(scope.displayName).tag(scope)
            }
        }
        .pickerStyle(.segmented)
        .compactMetricCard()
        .accessibilityIdentifier("day-flow-pattern-scope-picker")
    }

    @ViewBuilder
    private func summaryPills(for pattern: StepPattern) -> some View {
        HStack(spacing: 8) {
            if pattern.peakHourMedianSteps > 0 {
                let peakDate = peakHourDate(hour: pattern.peakHour)
                Text("Peak \(ActivityFormatting.shortHourLabel(for: peakDate)) · \(pattern.peakHourMedianSteps.formatted()) steps")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.stepDistance)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.stepDistance.opacity(0.12))
                    .clipShape(Capsule())
            }

            if let windowStart = pattern.mostActiveWindowStart,
               let windowEnd = pattern.mostActiveWindowEnd {
                Text(ActivityFormatting.formattedActiveWindowLabel(start: windowStart, end: windowEnd))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.stepAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.stepAccent.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }

    private func hourProfileCard(for pattern: StepPattern) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Typical Day Profile", systemImage: "chart.bar.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.stepInk)

            Text("Median steps by clock hour across this \(pattern.scope.displayName.lowercased()).")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.stepMuted)

            Chart(Array(pattern.hourlyMedianSteps.enumerated()), id: \.offset) { hour, steps in
                BarMark(
                    x: .value("Hour", hour),
                    y: .value("Steps", steps)
                )
                .foregroundStyle(hour == pattern.peakHour ? Color.stepDistance : Color.stepAccent.opacity(0.65))
                .cornerRadius(3)
            }
            .frame(height: 170)
            .chartXAxis {
                AxisMarks(values: .stride(by: 4)) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.stepAxisGrid)
                    AxisValueLabel {
                        if let hour = value.as(Int.self) {
                            Text(ActivityFormatting.shortHourLabel(for: peakHourDate(hour: hour)))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.stepAxis)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                    AxisGridLine()
                        .foregroundStyle(Color.stepAxisGrid)
                    AxisValueLabel()
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.stepAxis)
                }
            }
            .accessibilityIdentifier("day-flow-pattern-hour-profile")
        }
        .compactMetricCard()
    }

    private var dailyBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(selectedScope == .week ? "Week Detail" : "Month Detail")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.stepInk)
                Spacer()
                Text("\(period.activeDays) active")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.stepMuted)
            }

            VStack(spacing: 8) {
                ForEach(period.summaries) { summary in
                    DayFlowPatternDayRow(
                        summary: summary,
                        stepGoal: repository.goals.stepsPerDay,
                        maxSteps: maxDailySteps
                    )
                    .accessibilityIdentifier("day-flow-pattern-day-row-\(ActivityFormatting.dayKey(for: summary.dateStart))")
                }
            }
        }
        .compactMetricCard()
        .accessibilityIdentifier("day-flow-pattern-daily-breakdown")
    }

    private var coachBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Coach", systemImage: "sparkles")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.stepInk)

            if coachInsights.isEmpty {
                Text("Keep logging steps to unlock pattern coaching.")
                    .font(.caption)
                    .foregroundStyle(Color.stepMuted)
            } else {
                ForEach(coachInsights) { insight in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: insight.systemImage)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.stepAccent)
                            .frame(width: 18)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(insight.title)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.stepInk)
                            Text(insight.detail)
                                .font(.caption)
                                .foregroundStyle(Color.stepMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .compactMetricCard()
        .accessibilityIdentifier("day-flow-pattern-coach")
    }

    private func loadPattern() async {
        isLoading = true
        defer { isLoading = false }
        pattern = await repository.loadStepPattern(scope: selectedScope.activityScope, containing: date)
    }

    private func peakHourDate(hour: Int) -> Date {
        Calendar.current.date(byAdding: .hour, value: hour, to: Calendar.current.startOfDay(for: date)) ?? date
    }
}

private struct DayFlowPatternDayRow: View {
    let summary: DailyActivitySummary
    let stepGoal: Int
    let maxSteps: Int

    private var goalHit: Bool {
        summary.steps >= stepGoal
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(summary.dateStart, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.stepInk)
                .frame(minWidth: 72, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.stepAxisGrid)
                    Capsule()
                        .fill(barColor.opacity(summary.hasActivityData ? 0.78 : 0.24))
                        .frame(
                            width: summary.hasActivityData
                                ? max(6, proxy.size.width * Double(summary.steps) / Double(maxSteps))
                                : 0
                        )
                }
            }
            .frame(height: 10)

            Text(summary.steps.formatted())
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(summary.hasActivityData ? Color.stepInk : Color.stepMuted)
                .frame(minWidth: 56, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(goalHit ? "Goal" : (summary.hasActivityData ? "Open" : "—"))
                .font(.caption2.weight(.bold))
                .foregroundStyle(goalHit ? Color.stepAccent : Color.stepMuted)
                .frame(width: 34, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }

    private var barColor: Color {
        if goalHit { return .stepAccent }
        if !summary.workouts.isEmpty || summary.workoutMinutes > 0 { return .stepDistance }
        if summary.hasActivityData { return .stepEnergy }
        return .stepAxisGrid
    }
}
