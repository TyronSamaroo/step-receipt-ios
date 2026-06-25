import Charts
import SwiftUI

struct DayFlowCard: View {
    let summary: DailyActivitySummary
    let selectedDate: Date
    let distanceUnit: DistanceUnit
    var onPatternTap: (() -> Void)? = nil

    @State private var showHourlyRows = false
    @State private var selectedHourStart: Date?
    @State private var lastAnnouncedSelectionKey: String?

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

    private var selectionContextKey: String {
        let dayKey = ActivityFormatting.dayKey(for: selectedDate)
        return "\(dayKey)-\(summary.steps)-\(summary.buckets.count)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Day Flow", systemImage: "chart.bar.fill")
                    .font(.headline)
                    .foregroundStyle(Color.stepInk)
                Spacer(minLength: 8)
                if onPatternTap != nil {
                    Button {
                        onPatternTap?()
                    } label: {
                        Label("Week pattern", systemImage: "chart.xyaxis.line")
                            .labelStyle(.iconOnly)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.stepAccent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Week pattern")
                    .accessibilityIdentifier("day-flow-pattern-button")
                }
                Text("Hourly Steps")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.stepMuted)
            }

            headerCapsules
            selectionCallout

            if summary.buckets.isEmpty {
                Text("No hourly samples for this day.")
                    .font(.subheadline)
                    .foregroundStyle(Color.stepMuted)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            } else {
                dayFlowChart

                Button {
                    showHourlyRows.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Text("Hourly breakdown")
                        Image(systemName: showHourlyRows ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.bold))
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.stepAccent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("day-flow-hourly-breakdown-toggle")

                if showHourlyRows {
                    Divider()
                        .padding(.top, 4)

                    CompactHourlyTimetableRows(
                        buckets: summary.buckets,
                        distanceUnit: distanceUnit,
                        peakHourStart: digest.peakHourStart,
                        selectedHourStart: selectedHourStart
                    )
                }
            }
        }
        .metricCard()
        .accessibilityIdentifier("today-day-flow")
        .task(id: selectionContextKey) {
            applyDefaultSelection()
        }
        .onChange(of: selectedHourStart) { _, newValue in
            guard let newValue else {
                lastAnnouncedSelectionKey = nil
                return
            }

            let snapped = snapToNearestBucketHour(newValue)
            if snapped != newValue {
                selectedHourStart = snapped
                return
            }

            announceSelectionIfNeeded(for: snapped)
        }
    }

    private var dayFlowChart: some View {
        Chart(summary.buckets) { bucket in
            BarMark(
                x: .value("Hour", bucket.startDate, unit: .hour),
                y: .value("Steps", bucket.steps)
            )
            .foregroundStyle(barColor(for: bucket))
            .opacity(barOpacity(for: bucket))
            .cornerRadius(3)
        }
        .frame(height: 115)
        .chartXSelection(value: $selectedHourStart)
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
        .accessibilityLabel(dayFlowChartAccessibilityLabel)
        .accessibilityValue(dayFlowChartAccessibilityValue)
        .accessibilityAdjustableAction { direction in
            adjustSelectedHour(by: direction)
        }
    }

    @ViewBuilder
    private var selectionCallout: some View {
        if let hourStart = selectedHourStart,
           let bucket = bucket(matching: hourStart) {
            Text(selectionCalloutText(hour: hourStart, steps: bucket.steps))
                .font(.caption.weight(.bold))
                .foregroundStyle(selectionCalloutForeground)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(selectionCalloutBackground)
                .clipShape(Capsule())
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("day-flow-selection-callout")
                .accessibilityLabel(selectionCalloutAccessibilityLabel(hour: hourStart, steps: bucket.steps))
        }
    }

    @ViewBuilder
    private var headerCapsules: some View {
        let hasPeak = digest.peakHourStart != nil && digest.peakHourSteps > 0
        let hasActiveWindow = digest.mostActiveWindowStart != nil && digest.mostActiveWindowEnd != nil

        if hasPeak || hasActiveWindow {
            HStack(spacing: 8) {
                if let peakStart = digest.peakHourStart, digest.peakHourSteps > 0 {
                    peakCapsule(peakStart: peakStart, steps: digest.peakHourSteps)
                }

                if let windowStart = digest.mostActiveWindowStart,
                   let windowEnd = digest.mostActiveWindowEnd {
                    activeWindowCapsule(windowStart: windowStart, windowEnd: windowEnd)
                }
            }
        }
    }

    private func peakCapsule(peakStart: Date, steps: Int) -> some View {
        let isSelectedPeak = isSelectedHour(peakStart)

        return Text("Peak \(ActivityFormatting.shortHourLabel(for: peakStart)) · \(steps.formatted()) steps")
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.stepDistance)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.stepDistance.opacity(isSelectedPeak ? 0.22 : 0.12))
            .overlay {
                if isSelectedPeak {
                    Capsule()
                        .stroke(Color.stepDistance.opacity(0.55), lineWidth: 1)
                }
            }
            .clipShape(Capsule())
            .accessibilityIdentifier("day-flow-peak-pill")
            .onTapGesture {
                selectedHourStart = peakStart
            }
    }

    private func activeWindowCapsule(windowStart: Date, windowEnd: Date) -> some View {
        let containsSelection = selectedHourStart.map {
            isHour($0, within: windowStart, and: windowEnd)
        } ?? false

        return Text(ActivityFormatting.formattedActiveWindowLabel(start: windowStart, end: windowEnd))
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.stepAccent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.stepAccent.opacity(containsSelection ? 0.22 : 0.12))
            .overlay {
                if containsSelection {
                    Capsule()
                        .stroke(Color.stepAccent.opacity(0.55), lineWidth: 1)
                }
            }
            .clipShape(Capsule())
            .accessibilityIdentifier("day-flow-active-window-pill")
    }

    private func applyDefaultSelection() {
        if isToday, let currentHourStart {
            selectedHourStart = currentHourStart
            return
        }

        if let peakStart = digest.peakHourStart, digest.peakHourSteps > 0 {
            selectedHourStart = peakStart
            return
        }

        selectedHourStart = nil
        lastAnnouncedSelectionKey = nil
    }

    private func bucket(matching hourStart: Date) -> HealthMetricBucket? {
        summary.buckets.first { bucket in
            Calendar.current.isDate(bucket.startDate, equalTo: hourStart, toGranularity: .hour)
        }
    }

    private func snapToNearestBucketHour(_ date: Date) -> Date {
        guard let nearest = summary.buckets.min(by: {
            abs($0.startDate.timeIntervalSince(date)) < abs($1.startDate.timeIntervalSince(date))
        }) else {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: date)
            return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: selectedDate) ?? date
        }
        return nearest.startDate
    }

    private func isSelectedHour(_ hourStart: Date) -> Bool {
        guard let selectedHourStart else { return false }
        return Calendar.current.isDate(selectedHourStart, equalTo: hourStart, toGranularity: .hour)
    }

    private func isSelected(_ bucket: HealthMetricBucket) -> Bool {
        isSelectedHour(bucket.startDate)
    }

    private func isPeakHour(_ hourStart: Date) -> Bool {
        guard let peakStart = digest.peakHourStart, digest.peakHourSteps > 0 else { return false }
        return Calendar.current.isDate(hourStart, equalTo: peakStart, toGranularity: .hour)
    }

    private func isHour(_ hourStart: Date, within windowStart: Date, and windowEnd: Date) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: hourStart)
        let startHour = calendar.component(.hour, from: windowStart)
        let endHour = calendar.component(.hour, from: windowEnd)
        return hour >= startHour && hour <= endHour
    }

    private func barColor(for bucket: HealthMetricBucket) -> Color {
        if isSelected(bucket) {
            if isPeakHour(bucket.startDate) {
                return .stepDistance
            }
            if let currentHourStart,
               Calendar.current.isDate(bucket.startDate, equalTo: currentHourStart, toGranularity: .hour) {
                return .stepAccent
            }
            return .stepInk
        }

        if isPeakHour(bucket.startDate) {
            return .stepDistance
        }

        if let currentHourStart,
           Calendar.current.isDate(bucket.startDate, equalTo: currentHourStart, toGranularity: .hour) {
            return .stepAccent
        }

        return Color.stepAccent.opacity(0.55)
    }

    private func barOpacity(for bucket: HealthMetricBucket) -> Double {
        guard selectedHourStart != nil else { return 1 }
        return isSelected(bucket) ? 1 : 0.42
    }

    private var selectionCalloutForeground: Color {
        guard let selectedHourStart else { return Color.stepInk }
        if isPeakHour(selectedHourStart) {
            return Color.stepDistance
        }
        return Color.stepAccent
    }

    private var selectionCalloutBackground: Color {
        selectionCalloutForeground.opacity(0.14)
    }

    private func selectionCalloutText(hour: Date, steps: Int) -> String {
        "\(ActivityFormatting.shortHourLabel(for: hour)) · \(steps.formatted()) steps"
    }

    private func selectionCalloutAccessibilityLabel(hour: Date, steps: Int) -> String {
        "\(ActivityFormatting.shortHourLabel(for: hour)), \(steps.formatted()) steps selected"
    }

    private var dayFlowChartAccessibilityLabel: String {
        "Hourly step chart"
    }

    private var dayFlowChartAccessibilityValue: String {
        guard let selectedHourStart,
              let bucket = bucket(matching: selectedHourStart) else {
            return "No hour selected"
        }
        return selectionCalloutAccessibilityLabel(hour: selectedHourStart, steps: bucket.steps)
    }

    private func announceSelectionIfNeeded(for hourStart: Date) {
        guard let bucket = bucket(matching: hourStart) else { return }
        let key = "\(hourStart.timeIntervalSince1970)-\(bucket.steps)"
        guard key != lastAnnouncedSelectionKey else { return }
        lastAnnouncedSelectionKey = key
        AccessibilityNotification.Announcement(selectionCalloutAccessibilityLabel(hour: hourStart, steps: bucket.steps))
            .post()
    }

    private func adjustSelectedHour(by direction: AccessibilityAdjustmentDirection) -> Bool {
        guard !summary.buckets.isEmpty else { return false }

        let orderedBuckets = summary.buckets.sorted { $0.startDate < $1.startDate }
        let currentIndex: Int
        if let selectedHourStart,
           let index = orderedBuckets.firstIndex(where: { isSelectedHour($0.startDate) }) {
            currentIndex = index
        } else if let peakStart = digest.peakHourStart,
                  let index = orderedBuckets.firstIndex(where: {
                      Calendar.current.isDate($0.startDate, equalTo: peakStart, toGranularity: .hour)
                  }) {
            currentIndex = index
        } else {
            currentIndex = 0
        }

        let nextIndex: Int
        switch direction {
        case .increment:
            nextIndex = min(orderedBuckets.count - 1, currentIndex + 1)
        case .decrement:
            nextIndex = max(0, currentIndex - 1)
        @unknown default:
            return false
        }

        selectedHourStart = orderedBuckets[nextIndex].startDate
        return true
    }
}

struct CompactHourlyTimetableRows: View {
    let buckets: [HealthMetricBucket]
    let distanceUnit: DistanceUnit
    var peakHourStart: Date?
    var selectedHourStart: Date?

    @State private var showQuietHours = false

    private var quietHourCount: Int {
        buckets.filter { $0.steps == 0 }.count
    }

    private var visibleBuckets: [HealthMetricBucket] {
        showQuietHours ? buckets : buckets.filter { $0.steps > 0 }
    }

    private var usesScrollableRows: Bool {
        showQuietHours && visibleBuckets.count > 12
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
            } else {
                columnHeaderRow

                if usesScrollableRows {
                    ScrollView {
                        tabularRows
                    }
                    .frame(maxHeight: 240)
                } else {
                    tabularRows
                }
            }
        }
    }

    private var tabularRows: some View {
        VStack(spacing: 2) {
            ForEach(visibleBuckets) { bucket in
                tabularRow(bucket)
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
        let isSelected = isSelectedHour(bucket)

        return HStack(spacing: 6) {
            Text(ActivityFormatting.shortHourLabel(for: bucket.startDate))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.stepMuted)
                .frame(width: 32, alignment: .leading)

            HStack(spacing: 3) {
                Text(parts.stepsText)
                    .font(.caption.weight(isPeak || isSelected ? .heavy : .bold))
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
        .background(rowBackground(isPeak: isPeak, isSelected: isSelected))
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func rowBackground(isPeak: Bool, isSelected: Bool) -> Color {
        if isSelected {
            return Color.stepAccent.opacity(0.12)
        }
        if isPeak {
            return Color.stepDistance.opacity(0.08)
        }
        return Color.clear
    }

    private func isPeakHour(_ bucket: HealthMetricBucket) -> Bool {
        guard let peakHourStart else { return false }
        return Calendar.current.isDate(bucket.startDate, equalTo: peakHourStart, toGranularity: .hour)
    }

    private func isSelectedHour(_ bucket: HealthMetricBucket) -> Bool {
        guard let selectedHourStart else { return false }
        return Calendar.current.isDate(bucket.startDate, equalTo: selectedHourStart, toGranularity: .hour)
    }
}
