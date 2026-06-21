import Charts
import SwiftUI

struct DayFlowCard: View {
    let summary: DailyActivitySummary
    let selectedDate: Date
    let distanceUnit: DistanceUnit

    private var digest: TodayQuickDigest {
        TodayQuickDigestBuilder.digest(for: summary)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private var currentHourStart: Date? {
        guard isToday else { return nil }
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: selectedDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Day Flow", systemImage: "chart.bar.fill")
                    .font(.headline)
                    .foregroundStyle(Color.stepInk)
                Spacer(minLength: 8)
                Text("Hourly Steps")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.stepMuted)
            }

            headerCapsules

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
                    .foregroundStyle(barColor(for: bucket))
                    .cornerRadius(3)
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
                                Text(ActivityFormatting.shortHourLabel(for: date))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.stepAxis)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                        AxisGridLine()
                            .foregroundStyle(Color.stepAxisGrid)
                        AxisTick()
                            .foregroundStyle(Color.stepAxis)
                        AxisValueLabel()
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.stepAxis)
                    }
                }

                Divider()
                    .padding(.top, 4)

                CompactHourlyTimetableRows(
                    buckets: summary.buckets,
                    distanceUnit: distanceUnit,
                    peakHourStart: digest.peakHourStart
                )
            }
        }
        .metricCard()
        .accessibilityIdentifier("today-day-flow")
    }

    @ViewBuilder
    private var headerCapsules: some View {
        let hasPeak = digest.peakHourStart != nil && digest.peakHourSteps > 0
        let hasActiveWindow = digest.mostActiveWindowStart != nil && digest.mostActiveWindowEnd != nil

        if hasPeak || hasActiveWindow {
            HStack(spacing: 8) {
                if let peakStart = digest.peakHourStart, digest.peakHourSteps > 0 {
                    Text("Peak \(ActivityFormatting.shortHourLabel(for: peakStart)) · \(digest.peakHourSteps.formatted()) steps")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.stepDistance)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.stepDistance.opacity(0.12))
                        .clipShape(Capsule())
                        .accessibilityIdentifier("day-flow-peak-pill")
                }

                if let windowStart = digest.mostActiveWindowStart,
                   let windowEnd = digest.mostActiveWindowEnd {
                    Text(ActivityFormatting.formattedActiveWindowLabel(start: windowStart, end: windowEnd))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.stepAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.stepAccent.opacity(0.12))
                        .clipShape(Capsule())
                        .accessibilityIdentifier("day-flow-active-window-pill")
                }
            }
        }
    }

    private func barColor(for bucket: HealthMetricBucket) -> Color {
        let calendar = Calendar.current

        if let peakStart = digest.peakHourStart,
           calendar.isDate(bucket.startDate, equalTo: peakStart, toGranularity: .hour) {
            return .stepDistance
        }

        if let currentHourStart,
           calendar.isDate(bucket.startDate, equalTo: currentHourStart, toGranularity: .hour) {
            return .stepAccent
        }

        return Color.stepAccent.opacity(0.55)
    }
}

struct CompactHourlyTimetableRows: View {
    let buckets: [HealthMetricBucket]
    let distanceUnit: DistanceUnit
    var peakHourStart: Date?

    @State private var showQuietHours = false

    private var quietHourCount: Int {
        buckets.filter { $0.steps == 0 }.count
    }

    private var visibleBuckets: [HealthMetricBucket] {
        showQuietHours ? buckets : buckets.filter { $0.steps > 0 }
    }

    private var usesDenseGrid: Bool {
        visibleBuckets.count > 12
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if quietHourCount > 0 {
                Button {
                    showQuietHours.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Text(
                            showQuietHours
                                ? "Hide quiet hours"
                                : "\(quietHourCount) quiet hour\(quietHourCount == 1 ? "" : "s") hidden"
                        )
                        Image(systemName: showQuietHours ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.bold))
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.stepMuted)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("day-flow-quiet-hours-toggle")
            }

            if visibleBuckets.isEmpty {
                Text("No steps logged in active hours.")
                    .font(.caption)
                    .foregroundStyle(Color.stepMuted)
            } else if usesDenseGrid {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 2) {
                    ForEach(visibleBuckets) { bucket in
                        tabularRow(bucket)
                    }
                }
            } else {
                columnHeaderRow

                VStack(spacing: 2) {
                    ForEach(visibleBuckets) { bucket in
                        tabularRow(bucket)
                    }
                }
            }
        }
    }

    private var columnHeaderRow: some View {
        HStack(spacing: 6) {
            Text("Hour")
                .frame(width: 32, alignment: .leading)
            Text("Steps")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Dist")
                .frame(width: 52, alignment: .trailing)
            Text("Burn")
                .frame(width: 44, alignment: .trailing)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(Color.stepMuted)
        .padding(.bottom, 2)
    }

    private func tabularRow(_ bucket: HealthMetricBucket) -> some View {
        let parts = ActivityFormatting.formattedHourlyRowParts(
            steps: bucket.steps,
            distanceMeters: bucket.distanceMeters,
            activeEnergyKilocalories: bucket.activeEnergyKilocalories,
            unit: distanceUnit
        )
        let isPeak = isPeakHour(bucket)

        return HStack(spacing: 6) {
            Text(ActivityFormatting.shortHourLabel(for: bucket.startDate))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.stepMuted)
                .frame(width: 32, alignment: .leading)

            HStack(spacing: 3) {
                Text(parts.stepsText)
                    .font(.caption.weight(isPeak ? .heavy : .bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.stepInk)
                Text("steps")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.stepMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(parts.distanceText)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(Color.stepMuted)
                .frame(width: 52, alignment: .trailing)

            Text(parts.caloriesText)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(Color.stepMuted)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(isPeak ? Color.stepDistance.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func isPeakHour(_ bucket: HealthMetricBucket) -> Bool {
        guard let peakHourStart else { return false }
        return Calendar.current.isDate(bucket.startDate, equalTo: peakHourStart, toGranularity: .hour)
    }
}
