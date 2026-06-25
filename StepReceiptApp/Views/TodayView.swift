import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct TodayView: View {
    @EnvironmentObject private var repository: ActivityRepository
    @State private var shareImage: ShareImage?
    @State private var isWeatherDetailPresented = false
    @State private var isCoachInsightsPresented = false
    @State private var isDayFlowPatternPresented = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    healthConnectionCard

                    if let summary = repository.todaySummary {
                        todayHero(summary)
                        DayFlowCard(
                            summary: summary,
                            selectedDate: repository.selectedDate,
                            distanceUnit: repository.preferences.distanceUnit,
                            onPatternTap: { isDayFlowPatternPresented = true }
                        )
                        workoutSection(summary)
                        weekPulseCard
                        todayQuickDigestCard(summary)
                        healthSyncStatusCard
                    } else {
                        ProgressView("Loading activity")
                            .frame(maxWidth: .infinity, minHeight: 260)
                    }
                }
                .padding(16)
            }
            .refreshable {
                await repository.refresh()
            }
            .task {
                await repository.ensureDayWeather()
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
                        refreshToolbarIcon
                    }
                    .accessibilityLabel("Refresh")
                    .disabled(repository.isLoading)
                }
            }
        }
        .sheet(item: $shareImage) { shareImage in
            ShareSheet(items: [shareImage.image])
        }
        .sheet(isPresented: $isWeatherDetailPresented) {
            WeatherDetailSheet(date: repository.selectedDate)
                .environmentObject(repository)
        }
        .sheet(isPresented: $isDayFlowPatternPresented) {
            DayFlowPatternSheet(date: repository.selectedDate)
                .environmentObject(repository)
        }
        .sheet(isPresented: $isCoachInsightsPresented) {
            CoachInsightsSheet(insights: repository.todayCoachInsights())
                .environmentObject(repository)
        }
    }

    @ViewBuilder
    private func todayQuickDigestCard(_ summary: DailyActivitySummary) -> some View {
        let digest = TodayQuickDigestBuilder.digest(for: summary)

        switch digest.action {
        case .openLatestWorkout:
            if let workout = summary.workouts.first {
                NavigationLink {
                    WorkoutDetailView(workout: workout)
                } label: {
                    todayQuickDigestContent(digest, actionLabel: "Open latest workout", actionIcon: "chevron.right")
                }
                .buttonStyle(.plain)
            } else {
                todayQuickDigestButton(digest)
            }
        case .openTodayDetail:
            NavigationLink {
                DaySummaryDetailView(summary: summary)
            } label: {
                todayQuickDigestContent(digest, actionLabel: "Open today detail", actionIcon: "chevron.right")
            }
            .buttonStyle(.plain)
        case .refresh:
            todayQuickDigestButton(digest)
        }
    }

    private func todayQuickDigestButton(_ digest: TodayQuickDigest) -> some View {
        Button {
            Task { await repository.refresh() }
        } label: {
            todayQuickDigestContent(digest, actionLabel: repository.isLoading ? "Refreshing" : "Refresh now", actionIcon: StepReceiptSymbol.refresh)
        }
        .buttonStyle(.plain)
        .disabled(repository.isLoading)
    }

    private func todayQuickDigestContent(
        _ digest: TodayQuickDigest,
        actionLabel: String,
        actionIcon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Today at a glance", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(Color.stepInk)
                Spacer()
                HStack(spacing: 5) {
                    Text(actionLabel)
                    Image(systemName: actionIcon)
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.stepAccent)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                quickDigestStat(
                    "Peak hour",
                    quickDigestPeakHourText(digest),
                    "clock",
                    Color.stepDistance
                )
                quickDigestStat(
                    "Most active",
                    quickDigestActiveWindowText(digest),
                    "sun.max",
                    Color.stepEnergy
                )
                quickDigestStat(
                    "Workouts",
                    "\(digest.workoutCount)",
                    StepReceiptSymbol.workout,
                    Color.stepAccent
                )
                quickDigestStat(
                    "Calories",
                    ActivityFormatting.formattedCalories(digest.activeEnergyKilocalories),
                    StepReceiptSymbol.activeEnergy,
                    Color.stepEnergy
                )
            }
        }
        .metricCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("today-quick-digest")
    }

    private func quickDigestStat(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 24, height: 24)
                .background(color.opacity(0.14))
                .clipShape(Circle())

            Text(value)
                .font(.subheadline.monospacedDigit().weight(.bold))
                .foregroundStyle(Color.stepInk)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.stepMuted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.stepSurface.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func quickDigestPeakHourText(_ digest: TodayQuickDigest) -> String {
        guard let date = digest.peakHourStart, digest.peakHourSteps > 0 else {
            return "None yet"
        }
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func quickDigestActiveWindowText(_ digest: TodayQuickDigest) -> String {
        guard let start = digest.mostActiveWindowStart, let end = digest.mostActiveWindowEnd else {
            return "None yet"
        }
        return "\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))"
    }

    @ViewBuilder
    private var refreshToolbarIcon: some View {
        if repository.isLoading {
            ProgressView()
                .controlSize(.small)
        } else {
            Image(systemName: StepReceiptSymbol.refresh)
        }
    }

    @ViewBuilder
    private var healthSyncStatusCard: some View {
        if shouldShowHealthSyncStatus {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: healthSyncStatusIcon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(healthSyncStatusColor)
                    .frame(width: 34, height: 34)
                    .background(healthSyncStatusColor.opacity(0.14))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(healthSyncStatusTitle)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.stepInk)
                    Text(healthSyncStatusDetail)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.stepMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if repository.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color.stepAccent)
                }
            }
            .metricCard()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(healthSyncStatusTitle). \(healthSyncStatusDetail)")
        }
    }

    @ViewBuilder
    private var healthConnectionCard: some View {
        if repository.authorizationState != .authorized {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: StepReceiptSymbol.health)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.stepAccent)
                    .frame(width: 42, height: 42)
                    .background(Color.stepAccent.opacity(0.14))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(healthConnectionTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.stepInk)
                    Text(healthConnectionDetail)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.stepMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if repository.authorizationState != .unavailable {
                    Button {
                        Task { await repository.requestHealthAccess() }
                    } label: {
                        Text("Connect")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.stepAccent)
                    .accessibilityLabel("Connect Apple Health")
                }
            }
            .metricCard()
        }
    }

    private var healthConnectionTitle: String {
        switch repository.authorizationState {
        case .notDetermined:
            "Connect Apple Health once"
        case .deniedOrLimited:
            "Apple Health access needs attention"
        case .unavailable:
            "Apple Health is unavailable"
        case .authorized:
            ""
        }
    }

    private var healthConnectionDetail: String {
        switch repository.authorizationState {
        case .notDetermined:
            "Enable steps, distance, calories, workouts, and heart rate. After that, the app opens straight to Today."
        case .deniedOrLimited:
            "If anything is missing, reconnect here or allow StepReceipt in the Health app."
        case .unavailable:
            "This device cannot read Health data, so real activity will not populate here."
        case .authorized:
            ""
        }
    }

    private var shouldShowHealthSyncStatus: Bool {
        if repository.isLoading {
            return true
        }
        switch repository.healthRefreshStatus.outcome {
        case .refreshing, .partial, .cached, .failed:
            return true
        case .idle, .current:
            return false
        }
    }

    private var healthSyncStatusTitle: String {
        if repository.isLoading {
            return "Apple Health Sync"
        }

        switch repository.healthRefreshStatus.outcome {
        case .idle:
            return "Apple Health Sync"
        case .refreshing:
            return "Apple Health Sync"
        case .current:
            return "Apple Health Updated"
        case .partial:
            return "Partial Health Update"
        case .cached:
            return "Showing Saved Data"
        case .failed:
            return "Health Refresh Failed"
        }
    }

    private var healthSyncStatusDetail: String {
        if repository.isLoading {
            return "Refreshing steps, daily history, and workouts now."
        }

        let status = repository.healthRefreshStatus
        let timestamp = formattedRefreshTime(status.lastSuccessfulAt ?? status.lastCompletedAt)

        switch status.outcome {
        case .idle:
            return "Tap refresh to pull the latest steps from Apple Health."
        case .refreshing:
            return "Refreshing steps, daily history, and workouts now."
        case .current:
            return "Updated \(timestamp)."
        case .partial:
            return "Updated \(timestamp), but \(healthSyncIssueSummary(status.issue))"
        case .cached:
            return "Using saved data from this iPhone. Refresh again when Apple Health responds."
        case .failed:
            return "Apple Health did not respond. Refresh again after opening Health or unlocking the phone."
        }
    }

    private var healthSyncStatusIcon: String {
        if repository.isLoading {
            return "arrow.triangle.2.circlepath"
        }

        switch repository.healthRefreshStatus.outcome {
        case .idle:
            return StepReceiptSymbol.refresh
        case .refreshing:
            return "arrow.triangle.2.circlepath"
        case .current:
            return "checkmark.circle.fill"
        case .partial:
            return "exclamationmark.triangle.fill"
        case .cached:
            return "externaldrive.fill"
        case .failed:
            return "xmark.octagon.fill"
        }
    }

    private var healthSyncStatusColor: Color {
        if repository.isLoading {
            return Color.stepAccent
        }

        switch repository.healthRefreshStatus.outcome {
        case .idle, .refreshing, .current:
            return Color.stepAccent
        case .partial, .cached:
            return Color.stepEnergy
        case .failed:
            return Color.stepWarning
        }
    }

    private func formattedRefreshTime(_ date: Date?) -> String {
        guard let date else {
            return "just now"
        }

        if Calendar.current.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }

        return date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    private func healthSyncIssueSummary(_ issue: String?) -> String {
        guard let issue else {
            return "one Health read was incomplete."
        }

        return issue
            .split(separator: "\n")
            .first
            .map(String.init) ?? "one Health read was incomplete."
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
                    .frame(width: 30, height: 30)
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
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.bordered)
            .disabled(!canMoveForward)
        }
        .metricCard()
    }

    private func todayHero(_ summary: DailyActivitySummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            heroHeaderBlock(summary)

            heroDateControls

            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(summary.steps.formatted())
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.stepInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)
                            .contentTransition(.numericText())
                            .accessibilityIdentifier("today-hero-steps")
                        Text("steps")
                            .font(.callout.weight(.bold))
                            .foregroundStyle(Color.stepMuted)
                    }

                    Text(goalRemainingLine(for: summary))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(summary.stepGoalProgress >= 1 ? Color.stepAccent : Color.stepMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    if summary.stepGoalProgress >= 1 {
                        Label("Goal crushed", systemImage: "party.popper.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.stepAccent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.stepAccent.opacity(0.15))
                            .clipShape(Capsule())
                            .accessibilityIdentifier("today-goal-crushed")
                    }
                }

                Spacer(minLength: 8)

                ProgressRing(
                    progress: summary.stepGoalProgress,
                    lineWidth: 14,
                    labelFont: .subheadline.weight(.bold)
                )
                    .frame(width: 115, height: 115)
                    .accessibilityLabel("Step goal progress \(Int((summary.stepGoalProgress * 100).rounded())) percent")
            }

            heroMetricsRow(summary)
            heroCoachFooter(repository.todayCoachInsights())
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
        .shadow(color: Color.stepAccent.opacity(0.08), radius: 14, x: 0, y: 12)
        .accessibilityElement(children: .contain)
    }

    private var heroDateControls: some View {
        HStack(spacing: 10) {
            Button {
                Task { await repository.selectDate(Calendar.current.date(byAdding: .day, value: -1, to: repository.selectedDate) ?? repository.selectedDate) }
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 30, height: 30)
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
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .foregroundStyle(canMoveForward ? Color.stepAccent : Color.stepMuted.opacity(0.45))
            .background(Color.stepSurface.opacity(0.82))
            .clipShape(Circle())
            .disabled(!canMoveForward)
            .accessibilityLabel("Next day")
        }
    }

    private var isViewingToday: Bool {
        Calendar.current.isDateInToday(repository.selectedDate)
    }

    private var dailyGreeting: DailyGreeting {
        DailyGreetingBuilder.build(
            displayName: repository.preferences.displayName,
            date: repository.selectedDate,
            summary: repository.todaySummary ?? emptyGreetingSummary,
            history: repository.history,
            weekComparison: repository.weekComparison(containing: repository.selectedDate)
        )
    }

    private var emptyGreetingSummary: DailyActivitySummary {
        DailyActivitySummary(
            dateStart: Calendar.current.startOfDay(for: repository.selectedDate),
            steps: 0,
            distanceMeters: 0,
            activeEnergyKilocalories: 0,
            flightsClimbed: 0,
            workoutMinutes: 0,
            buckets: [],
            workouts: [],
            goals: repository.goals
        )
    }

    @ViewBuilder
    private func heroHeaderBlock(_ summary: DailyActivitySummary) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if isViewingToday, repository.preferences.dailyAffirmationEnabled {
                let greeting = dailyGreeting
                VStack(alignment: .leading, spacing: 5) {
                    Text(greeting.greetingLine)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.stepInk)
                        .accessibilityIdentifier("today-greeting-line")

                    Text(greeting.affirmationLine)
                        .font(.subheadline)
                        .foregroundStyle(Color.stepMuted)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .accessibilityIdentifier("today-affirmation-line")
                }
            } else {
                Text(heroDateLine(for: summary))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.stepAccent)
            }

            Spacer(minLength: 8)

            inlineWeatherChip
        }
    }

    @ViewBuilder
    private var inlineWeatherChip: some View {
        if repository.isLoadingDayWeather, repository.dayWeather == nil {
            ProgressView()
                .controlSize(.small)
                .frame(width: 44, height: 32)
                .accessibilityIdentifier("today-weather-strip")
        } else if let weather = repository.dayWeather {
            Button {
                isWeatherDetailPresented = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: weather.displayConditionSymbolName)
                        .font(.body)
                        .symbolRenderingMode(.multicolor)
                    Text(weather.formattedTemperatureFahrenheit)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.stepInk)
                        .monospacedDigit()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.stepSurface.opacity(0.82))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(weatherAccessibilityLabel(for: weather))
            .accessibilityHint("Opens detailed weather forecast")
            .accessibilityIdentifier("today-weather-strip")
        }
    }

    private func heroDateLine(for summary: DailyActivitySummary) -> String {
        let dateText = summary.dateStart.formatted(.dateTime.month(.wide).day())
        if Calendar.current.isDateInToday(summary.dateStart) {
            return "Today, \(dateText)"
        }
        return summary.dateStart.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private func goalRemainingLine(for summary: DailyActivitySummary) -> String {
        guard summary.stepGoalProgress < 1 else {
            return "Goal cleared at \(summary.goals.stepsPerDay.formatted())"
        }
        let remainingSteps = max(0, summary.goals.stepsPerDay - summary.steps)
        return "\(remainingSteps.formatted()) left to \(summary.goals.stepsPerDay.formatted())"
    }

    private func dayAverageHeartRateBPM(for summary: DailyActivitySummary) -> Double? {
        let samples = summary.workouts.flatMap(\.heartRateSamples)
        guard !samples.isEmpty else { return nil }
        return samples.reduce(0) { $0 + $1.beatsPerMinute } / Double(samples.count)
    }

    private func heroMetricsRow(_ summary: DailyActivitySummary) -> some View {
        let avgHeartRate = dayAverageHeartRateBPM(for: summary)
        let avgHRText = avgHeartRate.map { "\(Int($0.rounded())) bpm" } ?? "--"
        let heartTint = Color(red: 0.640, green: 0.430, blue: 1.000)
        let columns = [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]

        return LazyVGrid(columns: columns, spacing: 8) {
            heroMetricPill(
                "Distance",
                ActivityFormatting.formattedDistance(from: summary.distanceMeters, unit: repository.preferences.distanceUnit),
                StepReceiptSymbol.distance,
                Color.stepDistance
            )
            heroMetricPill(
                "Active Burn",
                ActivityFormatting.formattedCalories(summary.activeEnergyKilocalories),
                StepReceiptSymbol.activeEnergy,
                Color.stepEnergy
            )
            heroMetricPill("Avg HR", avgHRText, "heart.fill", heartTint)
            heroMetricPill(
                "Workout",
                ActivityFormatting.formattedMinutes(summary.workoutMinutes),
                StepReceiptSymbol.workout,
                Color.stepAccent
            )
        }
    }

    private func weatherAccessibilityLabel(for weather: DayWeatherSnapshot) -> String {
        var parts = [
            "Weather",
            weather.formattedTemperatureFahrenheitWithUnit,
            weather.displayConditionDescription,
            "feels like \(weather.displayApparentTemperatureFahrenheit)",
            "humidity \(weather.formattedHumidity)",
            "wind \(weather.displayWind)",
            "UV \(weather.displayUVIndex)"
        ]
        if let highLow = weather.formattedHighLowFahrenheit {
            parts.append(highLow)
        }
        return parts.joined(separator: ", ")
    }

    private func heroMetricPill(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 24, height: 24)
                .background(color.opacity(0.16))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.stepInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.stepMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 11)
        .background(Color.stepSurface.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func heroCoachFooter(_ insights: [TodayCoachInsight]) -> some View {
        if !insights.isEmpty, let primary = primaryCoachInsight(from: insights) {
            let secondary = insights.filter { $0.id != primary.id }

            VStack(alignment: .leading, spacing: 8) {
                Divider()
                    .padding(.top, 2)

                Label("Coach", systemImage: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.stepInk)

                Button {
                    isCoachInsightsPresented = true
                } label: {
                    coachRow(primary, showsCompeteLink: false)
                }
                .buttonStyle(.plain)

                if !secondary.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(secondary) { insight in
                                Button {
                                    isCoachInsightsPresented = true
                                } label: {
                                    coachInsightChip(insight)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.trailing, 16)
                    }
                    .scrollClipDisabled()
                }
            }
            .accessibilityIdentifier("today-hero-coach")
        }
    }

    private func primaryCoachInsight(from insights: [TodayCoachInsight]) -> TodayCoachInsight? {
        insights.max { coachKindRank($0.kind) < coachKindRank($1.kind) }
    }

    private func coachKindRank(_ kind: TodayCoachInsightKind) -> Int {
        switch kind {
        case .goal, .projection:
            4
        case .streak:
            3
        case .workout:
            2
        case .pace, .peakHour:
            1
        case .household, .general:
            0
        }
    }

    private func coachInsightChip(_ insight: TodayCoachInsight) -> some View {
        HStack(spacing: 5) {
            Image(systemName: insight.systemImage)
                .font(.caption2.weight(.bold))
                .foregroundStyle(coachAccent(for: insight.kind))
            Text(insight.title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.stepInk)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(coachAccent(for: insight.kind).opacity(0.12))
        .clipShape(Capsule())
    }

    private func coachRow(_ insight: TodayCoachInsight, showsCompeteLink: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: insight.systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(coachAccent(for: insight.kind))
                .frame(width: 28, height: 28)
                .background(coachAccent(for: insight.kind).opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(insight.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.stepInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text(insight.detail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.stepMuted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                if showsCompeteLink {
                    Text("Open Compete")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.stepAccent)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func coachAccent(for kind: TodayCoachInsightKind) -> Color {
        switch kind {
        case .goal, .projection:
            Color.stepAccent
        case .pace, .peakHour:
            Color.stepDistance
        case .workout:
            Color.stepEnergy
        case .household:
            Color.stepMuted
        case .streak:
            Color.stepWarning
        case .general:
            Color.stepAccent
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
                            Text(workout.startDate, format: .dateTime.hour().minute())
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.stepMuted)
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
                                let zone = repository.preferences.heartRateZoneConfiguration.template(for: averageHeartRate)
                                workoutHeroMetric("Avg HR", "\(Int(averageHeartRate.rounded())) bpm", "heart.fill", zone.color)
                            }
                        }

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            workoutHeroMetric("Duration", ActivityFormatting.formattedDuration(workout.durationMinutes * 60), StepReceiptSymbol.workout, style.accent)
                            if let burn = workout.activeEnergyKilocalories {
                                workoutHeroMetric("Burn", ActivityFormatting.formattedCalories(burn), StepReceiptSymbol.activeEnergy, Color.stepEnergy)
                            }
                            if let averageHeartRate = workout.averageHeartRateBPM {
                                let zone = repository.preferences.heartRateZoneConfiguration.template(for: averageHeartRate)
                                workoutHeroMetric("Avg HR", "\(Int(averageHeartRate.rounded())) bpm", "heart.fill", zone.color)
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        if workout.type == .stairClimbing, let burn = workout.activeEnergyKilocalories, workout.durationMinutes > 0 {
                            workoutHeroMetric("Burn rate", String(format: "%.1f/min", burn / workout.durationMinutes), StepReceiptSymbol.activeEnergy, Color.stepEnergy)
                        }
                        if workout.type == .strengthTraining, let tag = repository.workoutTag(for: workout) {
                            workoutHeroMetric("Tag", tag, "dumbbell", style.accent)
                        }
                        if workout.type.isCardioMovement, let distance = workout.distanceMeters, distance > 0 {
                            workoutHeroMetric("Distance", ActivityFormatting.formattedDistance(from: distance, unit: repository.preferences.distanceUnit), StepReceiptSymbol.distance, Color.stepDistance)
                        }
                        if let minHeartRate = workout.minHeartRateBPM, let maxHeartRate = workout.maxHeartRateBPM {
                            workoutHeroMetric(
                                "HR Range",
                                "\(Int(minHeartRate.rounded()))-\(Int(maxHeartRate.rounded())) bpm",
                                "heart",
                                Color.stepWarning
                            )
                        }
                    }

                    NavigationLink {
                        WorkoutCompareView(workout: workout, baseline: nil)
                    } label: {
                        Label("Compare session", systemImage: "arrow.left.arrow.right")
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(style.accent)
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
    private var weekPulseCard: some View {
        if let comparison = repository.weekComparison(containing: repository.selectedDate), !comparison.metrics.isEmpty {
            let pulseMetrics = comparison.metrics.filter {
                $0.title == "Average Steps" || $0.title == "Goal Days"
            }.prefix(2)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Week Pulse", systemImage: "waveform.path.ecg")
                        .font(.headline)
                        .foregroundStyle(Color.stepInk)
                    Spacer()
                    Text("vs prior week")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.stepMuted)
                }

                HStack(spacing: 8) {
                    ForEach(Array(pulseMetrics)) { metric in
                        weekPulseChip(metric)
                    }
                }
            }
            .metricCard()
            .accessibilityIdentifier("today-week-pulse")
        }
    }

    private func weekPulseChip(_ metric: PeriodComparisonMetric) -> some View {
        let shortTitle = metric.title == "Average Steps" ? "Steps" : "Goal days"
        let accent = (metric.isImprovement ?? false) ? Color.stepAccent : Color.stepWarning

        return VStack(alignment: .leading, spacing: 4) {
            Text(shortTitle)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.stepMuted)
            Text(metric.deltaText)
                .font(.subheadline.monospacedDigit().weight(.bold))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(accent.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func workoutSection(_ summary: DailyActivitySummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Workouts", systemImage: StepReceiptSymbol.workout)
                    .font(.headline)
                    .foregroundStyle(Color.stepInk)
                Spacer()
                if !summary.workouts.isEmpty {
                    Button("See all") {
                        repository.openActivityTab()
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.stepAccent)
                    .accessibilityIdentifier("today-workouts-see-all")
                }
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
        .accessibilityIdentifier("today-workouts-section")
    }

    private var canMoveForward: Bool {
        Calendar.current.startOfDay(for: repository.selectedDate) < repository.selectableDateRange().upperBound
    }

    private var canMoveBackward: Bool {
        Calendar.current.startOfDay(for: repository.selectedDate) > repository.selectableDateRange().lowerBound
    }

    private var selectedNavigationTitle: String {
        if isViewingToday, repository.preferences.dailyAffirmationEnabled {
            return ""
        }
        return isViewingToday ? "Today" : "Day"
    }

    private func shortHourLabel(for date: Date) -> String {
        ActivityFormatting.shortHourLabel(for: date)
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
    var lineWidth: CGFloat = 12
    var labelFont: Font = .caption.weight(.bold)

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.stepAccent.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(
                    AngularGradient(
                        colors: [Color.stepAccent, Color.stepDistance, Color.stepEnergy, Color.stepAccent],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text("\(Int((min(1, max(0, progress)) * 100).rounded()))%")
                .font(labelFont)
                .foregroundStyle(Color.stepInk)
        }
    }
}
