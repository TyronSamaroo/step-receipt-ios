import SwiftUI

struct CompetitionView: View {
    @EnvironmentObject private var repository: ActivityRepository

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    controls

                    if let receipt = repository.competitionReceipt {
                        CompetitionSummaryCard(receipt: receipt, distanceUnit: repository.preferences.distanceUnit)
                        leaderboard(receipt)
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
