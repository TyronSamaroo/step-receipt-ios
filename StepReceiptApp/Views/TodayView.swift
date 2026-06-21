import Charts
import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var repository: ActivityRepository
    @State private var shareImage: ShareImage?
    @State private var coachExpanded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    healthConnectionCard

                    if let summary = repository.todaySummary {
                        todayHero(summary)
                        welcomeBand(summary)
                        todayCoach(repository.todayCoachInsights())
                        weekPulseCard
                        primaryWorkoutCard(summary)
                        healthSyncStatusCard
                        hourlyChart(summary)
                        metricGrid(summary)
                        workoutSection(summary)
                        timetable(summary)
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

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                quickDigestStat(
                    "Peak hour",
                    quickDigestPeakHourText(digest),
                    "clock",
                    Color.stepDistance
                )
                quickDigestStat(
                    digest.goalReached ? "Goal" : "Left",
                    digest.goalReached ? "Hit" : "\(digest.remainingSteps.formatted())",
                    "target",
                    digest.goalReached ? Color.stepAccent : Color.stepEnergy
                )
                quickDigestStat(
                    "Workout",
                    "\(digest.workoutCount) · \(ActivityFormatting.formattedMinutes(digest.workoutMinutes))",
                    StepReceiptSymbol.workout,
                    Color.stepAccent
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
        return "\(date.formatted(date: .omitted, time: .shortened)) · \(digest.peakHourSteps.formatted())"
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
                    .frame(width: 34, height: 34)
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
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.bordered)
            .disabled(!canMoveForward)
        }
        .metricCard()
    }

    private func todayHero(_ summary: DailyActivitySummary) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(selectedNavigationTitle)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.stepInk)
                    Text(repository.selectedDate, format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.stepMuted)
                }

                Spacer(minLength: 0)

                weatherPill(summary)
            }

            heroDateControls

            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(summary.steps.formatted())")
                        .font(.system(size: 58, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.stepInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                        .contentTransition(.numericText())
                    Text("of \(summary.goals.stepsPerDay.formatted()) steps")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.stepMuted)
                    Text(goalStatusText(for: summary))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(summary.stepGoalProgress >= 1 ? Color.stepAccent : Color.stepInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                ProgressRing(progress: summary.stepGoalProgress)
                    .frame(width: 114, height: 114)
                    .accessibilityLabel("Step goal progress \(Int((summary.stepGoalProgress * 100).rounded())) percent")
            }

            if summary.stepGoalProgress >= 1 {
                Label("Goal crushed", systemImage: "party.popper.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.stepAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.stepAccent.opacity(0.15))
                    .clipShape(Capsule())
                    .accessibilityIdentifier("today-goal-crushed")
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    heroMetricPill("Distance", ActivityFormatting.formattedDistance(from: summary.distanceMeters, unit: repository.preferences.distanceUnit), StepReceiptSymbol.distance, Color.stepDistance)
                    heroMetricPill("Burn", ActivityFormatting.formattedCalories(summary.activeEnergyKilocalories), StepReceiptSymbol.activeEnergy, Color.stepEnergy)
                    heroMetricPill("Workout", ActivityFormatting.formattedMinutes(summary.workoutMinutes), StepReceiptSymbol.workout, Color.stepAccent)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    heroMetricPill("Distance", ActivityFormatting.formattedDistance(from: summary.distanceMeters, unit: repository.preferences.distanceUnit), StepReceiptSymbol.distance, Color.stepDistance)
                    heroMetricPill("Burn", ActivityFormatting.formattedCalories(summary.activeEnergyKilocalories), StepReceiptSymbol.activeEnergy, Color.stepEnergy)
                    heroMetricPill("Workout", ActivityFormatting.formattedMinutes(summary.workoutMinutes), StepReceiptSymbol.workout, Color.stepAccent)
                }
            }
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
        .shadow(color: Color.stepAccent.opacity(0.08), radius: 20, x: 0, y: 12)
        .accessibilityElement(children: .contain)
    }

    private var heroDateControls: some View {
        HStack(spacing: 10) {
            Button {
                Task { await repository.selectDate(Calendar.current.date(byAdding: .day, value: -1, to: repository.selectedDate) ?? repository.selectedDate) }
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 34, height: 34)
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
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(canMoveForward ? Color.stepAccent : Color.stepMuted.opacity(0.45))
            .background(Color.stepSurface.opacity(0.82))
            .clipShape(Circle())
            .disabled(!canMoveForward)
            .accessibilityLabel("Next day")
        }
    }

    private func weatherPill(_ summary: DailyActivitySummary) -> some View {
        let weather = weatherSummary(for: summary)
        return VStack(alignment: .trailing, spacing: 4) {
            Label(weather?.temperature ?? "-- F", systemImage: "thermometer.sun")
                .foregroundStyle(Color.stepEnergy)
            Label(weather?.humidity ?? "--%", systemImage: "water.waves")
                .foregroundStyle(Color.stepDistance)
        }
        .font(.caption.weight(.bold))
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.stepSurface.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Weather \(weather?.temperature ?? "not available"), humidity \(weather?.humidity ?? "not available")")
    }

    private func heroMetricPill(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 22, height: 22)
                .background(color.opacity(0.16))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.stepInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.stepMuted)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.stepSurface.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func todayCoach(_ insights: [TodayCoachInsight]) -> some View {
        if !insights.isEmpty {
            let visible = coachExpanded ? insights : Array(insights.prefix(2))
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Today Coach", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(Color.stepInk)
                    Spacer()
                    Text("Personal")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.stepAccent)
                }

                VStack(spacing: 10) {
                    ForEach(visible) { insight in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: insight.systemImage)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(coachAccent(for: insight.kind))
                                .frame(width: 28, height: 28)
                                .background(coachAccent(for: insight.kind).opacity(0.14))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 3) {
                                Text(insight.title)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color.stepInk)
                                Text(insight.detail)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.stepMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }

                if insights.count > 2 {
                    Button(coachExpanded ? "Show less" : "+\(insights.count - 2) more") {
                        coachExpanded.toggle()
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.stepAccent)
                }
            }
            .metricCard()
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

    private func welcomeBand(_ summary: DailyActivitySummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hey \(repository.preferences.displayName), welcome back.")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.stepInk)
            Text("Coach is tuned for today. \(goalStatusText(for: summary))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.stepMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .metricCard()
        .accessibilityIdentifier("today-welcome-band")
    }

    @ViewBuilder
    private var weekPulseCard: some View {
        if let comparison = repository.weekComparison(containing: repository.selectedDate), !comparison.metrics.isEmpty {
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

                ForEach(comparison.metrics.prefix(3)) { metric in
                    HStack {
                        Text(metric.title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.stepMuted)
                        Spacer()
                        Text(metric.deltaText)
                            .font(.caption.monospacedDigit().weight(.bold))
                            .foregroundStyle((metric.isImprovement ?? false) ? Color.stepAccent : Color.stepWarning)
                    }
                }
            }
            .metricCard()
            .accessibilityIdentifier("today-week-pulse")
        }
    }

    @ViewBuilder
    private func weatherStrip(_ summary: DailyActivitySummary) -> some View {
        if let weather = weatherSummary(for: summary) {
            HStack(spacing: 12) {
                Label("Weather", systemImage: "cloud.sun")
                    .foregroundStyle(Color.stepDistance)
                Spacer(minLength: 0)
                Label(weather.temperature, systemImage: "thermometer.sun")
                    .foregroundStyle(Color.stepEnergy)
                Label(weather.humidity, systemImage: "water.waves")
                    .foregroundStyle(Color.stepDistance)
                    .labelStyle(.titleAndIcon)
            }
            .overlay(alignment: .bottomLeading) {
                Text(weather.source)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.stepMuted.opacity(0.86))
                    .lineLimit(1)
                    .offset(y: 18)
            }
            .font(.subheadline.weight(.bold))
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 20)
            .background(Color.stepSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 6)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Weather \(weather.temperature), humidity \(weather.humidity)")
        }
    }

    private func hourlyChart(_ summary: DailyActivitySummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hourly Steps")
                .font(.headline)
                .foregroundStyle(Color.stepInk)

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
                    .foregroundStyle(Color.stepAccent.gradient)
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
                                Text(shortHourLabel(for: date))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.stepAxis)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) {
                        AxisGridLine()
                            .foregroundStyle(Color.stepAxisGrid)
                        AxisTick()
                            .foregroundStyle(Color.stepAxis)
                        AxisValueLabel()
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.stepAxis)
                    }
                }
            }
        }
        .metricCard()
    }

    private func metricGrid(_ summary: DailyActivitySummary) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            if repository.preferences.shows(.distance) {
                MetricTile(
                    title: DashboardMetric.distance.displayName,
                    value: ActivityFormatting.formattedDistance(from: summary.distanceMeters, unit: repository.preferences.distanceUnit),
                    icon: StepReceiptSymbol.distance,
                    color: Color.stepDistance
                )
            }
            if repository.preferences.shows(.activeEnergy) {
                MetricTile(
                    title: DashboardMetric.activeEnergy.displayName,
                    value: ActivityFormatting.formattedCalories(summary.activeEnergyKilocalories),
                    icon: StepReceiptSymbol.activeEnergy,
                    color: Color.stepEnergy
                )
            }
            if repository.preferences.shows(.flights) {
                MetricTile(
                    title: DashboardMetric.flights.displayName,
                    value: "\(summary.flightsClimbed)",
                    icon: StepReceiptSymbol.stairClimbing,
                    color: Color(red: 0.640, green: 0.430, blue: 1.000)
                )
            }
            if repository.preferences.shows(.workoutMinutes) {
                MetricTile(
                    title: DashboardMetric.workoutMinutes.displayName,
                    value: ActivityFormatting.formattedMinutes(summary.workoutMinutes),
                    icon: StepReceiptSymbol.workout,
                    color: Color.stepAccent
                )
            }
        }
    }

    private func workoutSection(_ summary: DailyActivitySummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Workouts")
                    .font(.headline)
                Spacer()
                Text("\(summary.workouts.count)")
                    .foregroundStyle(Color.stepMuted)
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
    }

    private func timetable(_ summary: DailyActivitySummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timetable")
                .font(.headline)

            if summary.buckets.isEmpty {
                Text("No timetable entries for this day.")
                    .font(.caption)
                    .foregroundStyle(Color.stepMuted)
            } else {
                CompactHourlyTimetableRows(
                    buckets: summary.buckets,
                    distanceUnit: repository.preferences.distanceUnit
                )
            }
        }
        .metricCard()
    }

    private func goalStatusText(for summary: DailyActivitySummary) -> String {
        guard summary.stepGoalProgress < 1 else {
            return "Goal cleared. Keep the streak intact."
        }

        let remainingSteps = max(0, summary.goals.stepsPerDay - summary.steps)
        return "\(remainingSteps.formatted()) steps left."
    }

    private func weatherSummary(for summary: DailyActivitySummary) -> (temperature: String, humidity: String, source: String)? {
        guard let workout = summary.workouts.first(where: {
            $0.weatherTemperatureCelsius != nil || $0.weatherHumidityPercent != nil
        }) else {
            return nil
        }

        let temperature = workout.weatherTemperatureCelsius.map { "\(Int(celsiusToFahrenheit($0).rounded())) F" } ?? "-- F"
        let humidity = workout.weatherHumidityPercent.map { "\(Int($0.rounded()))%" } ?? "--%"
        return (temperature, humidity, workout.displayTitle)
    }

    private func celsiusToFahrenheit(_ celsius: Double) -> Double {
        celsius * 9 / 5 + 32
    }

    private var canMoveForward: Bool {
        Calendar.current.startOfDay(for: repository.selectedDate) < repository.selectableDateRange().upperBound
    }

    private var canMoveBackward: Bool {
        Calendar.current.startOfDay(for: repository.selectedDate) > repository.selectableDateRange().lowerBound
    }

    private var selectedNavigationTitle: String {
        Calendar.current.isDateInToday(repository.selectedDate) ? "Today" : "Day"
    }

    private func shortHourLabel(for date: Date) -> String {
        ActivityFormatting.shortHourLabel(for: date)
    }
}

struct CompactHourlyTimetableRows: View {
    let buckets: [HealthMetricBucket]
    let distanceUnit: DistanceUnit

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
                    Text(
                        showQuietHours
                            ? "Hide quiet hours"
                            : "\(quietHourCount) quiet hour\(quietHourCount == 1 ? "" : "s") hidden"
                    )
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.stepMuted)
                }
                .buttonStyle(.plain)
            }

            if visibleBuckets.isEmpty {
                Text("No steps logged in active hours.")
                    .font(.caption)
                    .foregroundStyle(Color.stepMuted)
            } else if usesDenseGrid {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 2) {
                    ForEach(visibleBuckets) { bucket in
                        compactRow(bucket)
                    }
                }
            } else {
                VStack(spacing: 2) {
                    ForEach(visibleBuckets) { bucket in
                        compactRow(bucket)
                    }
                }
            }
        }
    }

    private func compactRow(_ bucket: HealthMetricBucket) -> some View {
        HStack(spacing: 6) {
            Text(ActivityFormatting.shortHourLabel(for: bucket.startDate))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.stepMuted)
                .frame(width: 28, alignment: .leading)

            Text(
                ActivityFormatting.compactHourlyDetail(
                    steps: bucket.steps,
                    distanceMeters: bucket.distanceMeters,
                    activeEnergyKilocalories: bucket.activeEnergyKilocalories,
                    unit: distanceUnit
                )
            )
            .font(.caption)
            .foregroundStyle(Color.stepInk)
            .lineLimit(1)
            .minimumScaleFactor(0.75)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 1)
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

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.stepAccent.opacity(0.18), lineWidth: 10)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(
                    AngularGradient(
                        colors: [Color.stepAccent, Color.stepDistance, Color.stepEnergy, Color.stepAccent],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text("\(Int((min(1, max(0, progress)) * 100).rounded()))%")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.stepInk)
        }
    }
}
