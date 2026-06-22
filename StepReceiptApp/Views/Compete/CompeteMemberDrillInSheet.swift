import SwiftUI

struct CompeteMemberDrillInSelection: Identifiable {
    let id: UUID
    let row: LeaderboardRow

    init(row: LeaderboardRow) {
        self.id = row.competitor.id
        self.row = row
    }
}

private enum CompeteMemberDrillInScope: String, CaseIterable, Identifiable {
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

struct CompeteMemberDrillInSheet: View {
    @EnvironmentObject private var repository: ActivityRepository
    @Environment(\.dismiss) private var dismiss

    let row: LeaderboardRow
    let metric: CompetitionMetric
    let distanceUnit: DistanceUnit

    @State private var selectedScope: CompeteMemberDrillInScope = .week

    private var breakdown: CompeteMemberPeriodBreakdown {
        repository.competeMemberPeriodBreakdown(
            for: row.competitor,
            scope: selectedScope.activityScope,
            metric: metric
        )
    }

    private var heatmapPeriod: PeriodActivitySummary {
        repository.competeMemberHeatmapPeriod(
            for: row.competitor,
            scope: selectedScope.activityScope
        )
    }

    private var maxDayScore: Double {
        max(1, breakdown.days.map { $0.metricValue(metric) }.max() ?? 1)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    headerCard
                    scopePicker
                    summaryTiles
                    PeriodHeatMap(period: heatmapPeriod)
                        .accessibilityIdentifier("compete-member-drill-in-heatmap")
                    dailyBreakdownCard
                }
                .padding(16)
            }
            .background(Color.stepBackground)
            .navigationTitle(row.competitor.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("compete-member-drill-in-done")
                }
            }
            .accessibilityIdentifier("compete-member-drill-in-sheet")
        }
    }

    private var headerCard: some View {
        HStack(spacing: 14) {
            Text(row.competitor.initials)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(row.isCurrentUser ? Color.stepAccent : Color.stepDistance)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(row.competitor.displayName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.stepInk)
                    if row.rank == 1 {
                        Image(systemName: "crown.fill")
                            .font(.caption)
                            .foregroundStyle(Color.stepWarning)
                    }
                }

                Text(memberSubtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.stepMuted)

                Text(breakdown.periodLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.stepAccent)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text("#\(row.rank)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(row.rank == 1 ? Color.stepAccent : Color.stepMuted)
                Text(CompeteFormatting.formattedScore(breakdown.totalScore, metric: metric, distanceUnit: distanceUnit))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.stepInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(metric.displayName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.stepMuted)
            }
        }
        .metricCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("compete-member-drill-in-header")
    }

    private var memberSubtitle: String {
        if row.isCurrentUser {
            return "Your household totals"
        }
        return "Shared daily summaries"
    }

    private var scopePicker: some View {
        Picker("Period", selection: $selectedScope) {
            ForEach(CompeteMemberDrillInScope.allCases) { scope in
                Text(scope.displayName).tag(scope)
            }
        }
        .pickerStyle(.segmented)
        .compactMetricCard()
        .accessibilityIdentifier("compete-member-drill-in-scope-picker")
    }

    private var summaryTiles: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            CompactMetricTile(
                title: "Daily Avg",
                value: CompeteFormatting.formattedScore(breakdown.dailyAverageScore, metric: metric, distanceUnit: distanceUnit),
                icon: "calendar"
            )
            CompactMetricTile(
                title: "Goal Days",
                value: "\(breakdown.goalHitDays)/\(max(1, breakdown.days.count))",
                icon: "target"
            )
            CompactMetricTile(
                title: "Active Days",
                value: breakdown.activeDays.formatted(),
                icon: StepReceiptSymbol.activeEnergy
            )
            CompactMetricTile(
                title: "Best Day",
                value: bestDayLabel,
                icon: "star.fill",
                color: .stepWarning
            )
        }
        .compactMetricCard()
        .accessibilityIdentifier("compete-member-drill-in-summary-tiles")
    }

    private var bestDayLabel: String {
        guard let bestDay = breakdown.bestDay else { return "—" }
        return CompeteFormatting.formattedScore(bestDay.metricValue(metric), metric: metric, distanceUnit: distanceUnit)
    }

    private var dailyBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(selectedScope == .week ? "Week Detail" : "Month Detail")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.stepInk)
                Spacer()
                Text("\(breakdown.activeDays) active")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.stepMuted)
            }

            VStack(spacing: 8) {
                ForEach(breakdown.days) { day in
                    CompeteMemberDayRow(
                        day: day,
                        metric: metric,
                        distanceUnit: distanceUnit,
                        stepGoal: repository.goals.stepsPerDay,
                        maxScore: maxDayScore
                    )
                    .accessibilityIdentifier("compete-member-drill-in-day-row-\(day.dayKey)")
                }
            }
        }
        .compactMetricCard()
        .accessibilityIdentifier("compete-member-drill-in-daily-breakdown")
    }
}

private struct CompeteMemberDayRow: View {
    let day: CompeteMemberDayBreakdown
    let metric: CompetitionMetric
    let distanceUnit: DistanceUnit
    let stepGoal: Int
    let maxScore: Double

    private var score: Double {
        day.metricValue(metric)
    }

    private var goalHit: Bool {
        day.steps >= stepGoal
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(day.dateStart, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.stepInk)
                .frame(minWidth: 72, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.stepAxisGrid)
                    Capsule()
                        .fill(barColor.opacity(day.hasActivity ? 0.78 : 0.24))
                        .frame(width: day.hasActivity ? max(6, proxy.size.width * score / maxScore) : 0)
                }
            }
            .frame(height: 10)

            Text(CompeteFormatting.formattedScore(score, metric: metric, distanceUnit: distanceUnit))
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(day.hasActivity ? Color.stepInk : Color.stepMuted)
                .frame(minWidth: 56, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(goalHit ? "Goal" : (day.hasActivity ? "Open" : "—"))
                .font(.caption2.weight(.bold))
                .foregroundStyle(goalHit ? Color.stepAccent : Color.stepMuted)
                .frame(width: 34, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var barColor: Color {
        if goalHit { return .stepAccent }
        if day.workoutMinutes > 0 { return .stepDistance }
        if day.hasActivity { return .stepEnergy }
        return .stepAxisGrid
    }

    private var accessibilityLabel: String {
        let dateLabel = day.dateStart.formatted(date: .abbreviated, time: .omitted)
        if day.hasActivity {
            return "\(dateLabel), \(CompeteFormatting.formattedScore(score, metric: metric, distanceUnit: distanceUnit)), \(goalHit ? "goal hit" : "open")"
        }
        return "\(dateLabel), no activity"
    }
}
