import SwiftUI

struct CompetitionView: View {
    @EnvironmentObject private var repository: ActivityRepository
    @State private var isPresentingCheckIn = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    controls

                    if let receipt = repository.competitionReceipt {
                        CompetitionSummaryCard(receipt: receipt, distanceUnit: repository.preferences.distanceUnit)
                        leaderboard(receipt)
                        localCheckIns
                        privacyNote
                    } else {
                        ContentUnavailableView(
                            "No competition data",
                            systemImage: StepReceiptSymbol.competitionTab,
                            description: Text("Connect Apple Health or keep using sample mode to preview a friendly board.")
                        )
                        .padding(.top, 80)
                    }
                }
                .padding(16)
            }
            .safeAreaPadding(.bottom, 84)
            .background(Color.stepBackground)
            .navigationTitle("Compete")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingCheckIn = true
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                    .accessibilityLabel("Add friend check-in")
                }
            }
            .sheet(isPresented: $isPresentingCheckIn) {
                CompetitionCheckInSheet()
                    .environmentObject(repository)
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Window", selection: $repository.competitionWindow) {
                ForEach(CompetitionWindow.allCases) { window in
                    Text(window.displayName).tag(window)
                }
            }
            .pickerStyle(.segmented)

            Picker("Metric", selection: $repository.competitionMetric) {
                ForEach(CompetitionMetric.allCases) { metric in
                    Text(metric.displayName).tag(metric)
                }
            }
            .pickerStyle(.menu)

            Button {
                isPresentingCheckIn = true
            } label: {
                Label("Add Check-In", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.stepAccent)
        }
        .metricCard()
    }

    private func leaderboard(_ receipt: CompetitionReceipt) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Leaderboard")
                    .font(.headline)
                Spacer()
                Text(receipt.window.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.stepMuted)
            }

            ForEach(receipt.rows) { row in
                LeaderboardRowView(row: row, distanceUnit: repository.preferences.distanceUnit)
            }
        }
        .metricCard()
    }

    private var localCheckIns: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Friend Check-Ins")
                    .font(.headline)
                Spacer()
                Text("\(repository.localCompetitionCheckIns.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.stepMuted)
            }

            if repository.localCompetitionCheckIns.isEmpty {
                Text("No local check-ins yet.")
                    .font(.subheadline)
                    .foregroundStyle(Color.stepMuted)
            } else {
                ForEach(repository.localCompetitionCheckIns.prefix(8)) { checkIn in
                    CompetitionCheckInRow(
                        checkIn: checkIn,
                        competitor: repository.localCompetitors.first { $0.id == checkIn.competitorID },
                        distanceUnit: repository.preferences.distanceUnit
                    ) {
                        repository.removeLocalCompetitionCheckIn(checkIn)
                    }
                }
            }
        }
        .metricCard()
    }

    private var privacyNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Privacy-safe by design", systemImage: "lock.shield")
                .font(.headline)
                .foregroundStyle(Color.stepInk)
            Text("Competition uses daily aggregate totals only. Raw HealthKit samples, hourly buckets, and workout details stay on-device.")
                .font(.footnote)
                .foregroundStyle(Color.stepMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .metricCard()
    }
}

struct CompetitionCheckInSheet: View {
    @EnvironmentObject private var repository: ActivityRepository
    @Environment(\.dismiss) private var dismiss
    @State private var displayName = ""
    @State private var date = Date()
    @State private var steps = ""
    @State private var distance = ""
    @State private var activeEnergy = ""
    @State private var workoutMinutes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Friend") {
                    TextField("Name", text: $displayName)
                        .textInputAutocapitalization(.words)
                    DatePicker("Day", selection: $date, in: repository.selectableDateRange(), displayedComponents: .date)
                }

                Section("Totals") {
                    TextField("Steps", text: $steps)
                        .keyboardType(.numberPad)
                    TextField(repository.preferences.distanceUnit == .miles ? "Distance miles" : "Distance kilometers", text: $distance)
                        .keyboardType(.decimalPad)
                    TextField("Active calories", text: $activeEnergy)
                        .keyboardType(.numberPad)
                    TextField("Workout minutes", text: $workoutMinutes)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Check-In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        repository.addLocalCompetitionCheckIn(
                            displayName: displayName,
                            date: date,
                            steps: Int(steps) ?? 0,
                            distanceMeters: distanceMeters,
                            activeEnergyKilocalories: Double(activeEnergy) ?? 0,
                            workoutMinutes: Double(workoutMinutes) ?? 0
                        )
                        dismiss()
                    }
                    .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if displayName.isEmpty, let first = repository.localCompetitors.first {
                    displayName = first.displayName
                }
            }
        }
    }

    private var distanceMeters: Double {
        let value = Double(distance) ?? 0
        switch repository.preferences.distanceUnit {
        case .miles:
            return value * 1_609.344
        case .kilometers:
            return value * 1_000
        }
    }
}

struct CompetitionCheckInRow: View {
    let checkIn: LocalCompetitionCheckIn
    let competitor: CompetitorProfile?
    let distanceUnit: DistanceUnit
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(competitor?.initials ?? "FR")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.stepDistance)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(competitor?.displayName ?? "Friend")
                    .font(.headline)
                    .foregroundStyle(Color.stepInk)
                    .lineLimit(1)
                Text("\(checkIn.dayKey) · \(checkIn.steps.formatted()) steps · \(ActivityFormatting.formattedDistance(from: checkIn.distanceMeters, unit: distanceUnit)) · \(ActivityFormatting.formattedMinutes(checkIn.workoutMinutes))")
                    .font(.caption)
                    .foregroundStyle(Color.stepMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.stepMuted)
            .accessibilityLabel("Delete check-in")
        }
        .padding(12)
        .background(Color.stepBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct CompetitionSummaryCard: View {
    let receipt: CompetitionReceipt
    let distanceUnit: DistanceUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("FRIENDLY BOARD")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.stepAccent)
                    Text(receipt.metric.displayName)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.stepInk)
                }
                Spacer()
                Image(systemName: StepReceiptSymbol.competitionTab)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.stepAccent)
            }

            Text(headlineText)
                .font(.headline)
                .foregroundStyle(Color.stepInk)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                summaryStat("Rank", receipt.currentUserRank.map { "#\($0)" } ?? "-")
                summaryStat("People", "\(receipt.rows.count)")
                if let gap = receipt.gapToNextRank {
                    summaryStat("Gap", formattedScore(gap, metric: receipt.metric, distanceUnit: distanceUnit))
                }
            }
        }
        .metricCard()
    }

    private func summaryStat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.headline)
                .foregroundStyle(Color.stepInk)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.stepMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headlineText: String {
        guard let rank = receipt.currentUserRank else {
            return "Connect summaries to start a friendly board."
        }
        if rank == 1 {
            return "You are leading on \(receipt.metric.displayName.lowercased())."
        }
        if let gap = receipt.gapToNextRank {
            return "\(formattedScore(gap, metric: receipt.metric, distanceUnit: distanceUnit)) to move up one spot."
        }
        return receipt.headline
    }
}

struct LeaderboardRowView: View {
    let row: LeaderboardRow
    let distanceUnit: DistanceUnit

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(row.rank)")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.stepMuted)
                .frame(width: 34, alignment: .leading)

            Text(row.competitor.initials)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(row.isCurrentUser ? Color.stepAccent : Color.stepDistance)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(row.competitor.displayName)
                    .font(.headline)
                    .foregroundStyle(Color.stepInk)
                    .lineLimit(1)
                Text(row.isCurrentUser ? "Your aggregate summary" : "Shared daily summary")
                    .font(.caption)
                    .foregroundStyle(Color.stepMuted)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            Text(formattedScore(row.score, metric: row.metric, distanceUnit: distanceUnit))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.stepInk)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(12)
        .background(row.isCurrentUser ? Color.stepAccent.opacity(0.10) : Color.stepBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private func formattedScore(_ score: Double, metric: CompetitionMetric, distanceUnit: DistanceUnit) -> String {
    switch metric {
    case .steps:
        "\(Int(score.rounded()).formatted())"
    case .distance:
        ActivityFormatting.formattedDistance(from: score, unit: distanceUnit)
    case .activeEnergy:
        ActivityFormatting.formattedCalories(score)
    case .workoutMinutes:
        ActivityFormatting.formattedMinutes(score)
    }
}
