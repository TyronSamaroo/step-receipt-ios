import SwiftUI
import UIKit

enum CompeteInviteCodeClipboard {
    static func normalizedCodeFromClipboard() -> String? {
        guard let value = UIPasteboard.general.string else { return nil }
        return SharedCompetitionSettings.normalizedInviteCodeCandidates(from: value).first
    }
}

struct CompetitionInviteShare: Identifiable {
    let id = UUID()
    let code: String

    var joinURL: URL? {
        CompeteJoinDeepLink.joinURL(for: code)
    }

    var message: String {
        var lines = [
            "Join my StrideSlip household board:"
        ]
        if let joinURL {
            lines.append(joinURL.absoluteString)
        } else {
            lines.append("Code: \(code)")
        }
        lines.append("")
        lines.append("Or open StrideSlip → Compete and paste the code.")
        return lines.joined(separator: "\n")
    }
}

struct CompeteSampleBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "eye")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.stepWarning)
            VStack(alignment: .leading, spacing: 3) {
                Text("Preview board")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.stepInk)
                Text("Connect Apple Health to compete for real. Preview names are sample data only.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.stepMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.stepWarning.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityIdentifier("compete-sample-banner")
    }
}

struct CompeteAttentionCard: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.stepWarning)
                .frame(width: 34, height: 34)
                .background(Color.stepWarning.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.stepInk)
                Text(detail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.stepMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.stepWarning.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityIdentifier("compete-attention-card")
    }
}

struct CompeteSyncStatusRow: View {
    let state: CompetitionSyncState
    let canSync: Bool
    let canPublishEntries: Bool

    private var isSyncing: Bool {
        state == .syncing
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.14))
                if isSyncing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(statusColor)
                } else {
                    Image(systemName: statusIcon)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(statusColor)
                }
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text("Sync Status")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.stepMuted)
                Text(CompetitionSyncPresentation.statusTitle(for: state))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.stepInk)
            }

            Spacer(minLength: 6)

            Text(CompetitionSyncPresentation.statusDetail(
                state: state,
                canSync: canSync,
                canPublishEntries: canPublishEntries
            ))
            .font(.caption.weight(.semibold))
            .foregroundStyle(detailColor)
            .multilineTextAlignment(.trailing)
            .lineLimit(3)
            .minimumScaleFactor(0.82)
        }
        .padding(10)
        .background(Color.stepBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("compete-sync-status-row")
    }

    private var statusIcon: String {
        switch state {
        case .off: "power"
        case .idle: "checkmark.circle"
        case .syncing: StepReceiptSymbol.refresh
        case .synced: "checkmark.circle.fill"
        case .unavailable: "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch state {
        case .synced: .stepAccent
        case .syncing, .idle: .stepDistance
        case .off: .stepMuted
        case .unavailable: .stepWarning
        }
    }

    private var detailColor: Color {
        switch state {
        case .unavailable: .stepWarning
        default: .stepMuted
        }
    }
}

struct CompetitionSummaryCard: View {
    let receipt: CompetitionReceipt
    let distanceUnit: DistanceUnit
    var showsSampleLabel: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(showsSampleLabel ? "PREVIEW BOARD" : "HOUSEHOLD BOARD")
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
                    summaryStat("Gap", CompeteFormatting.formattedScore(gap, metric: receipt.metric, distanceUnit: distanceUnit))
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
            return "Connect summaries to start a household board."
        }
        if rank == 1, let challenger = challengerName(from: receipt) {
            return "You're leading — \(challenger) is chasing you on \(receipt.metric.displayName.lowercased())."
        }
        if rank == 1 {
            return "You are leading on \(receipt.metric.displayName.lowercased())."
        }
        if let gap = receipt.gapToNextRank {
            return "\(CompeteFormatting.formattedScore(gap, metric: receipt.metric, distanceUnit: distanceUnit)) to move up one spot."
        }
        return receipt.headline
    }

    private func challengerName(from receipt: CompetitionReceipt) -> String? {
        guard let currentRank = receipt.currentUserRank else { return nil }
        return receipt.rows.first { $0.rank == currentRank + 1 }?.competitor.displayName
    }
}

struct LeaderboardRowView: View {
    let row: LeaderboardRow
    let distanceUnit: DistanceUnit
    var isSampleRow: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(row.rank)")
                .font(.caption.weight(.bold))
                .foregroundStyle(row.rank == 1 ? Color.stepAccent : Color.stepMuted)
                .frame(width: 34, alignment: .leading)

            Text(row.competitor.initials)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(row.isCurrentUser ? Color.stepAccent : Color.stepDistance)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(row.competitor.displayName)
                        .font(.headline)
                        .foregroundStyle(Color.stepInk)
                        .lineLimit(1)
                    if row.rank == 1 {
                        Image(systemName: "crown.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.stepWarning)
                    }
                }
                Text(rowSubtitle)
                    .font(.caption)
                    .foregroundStyle(Color.stepMuted)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            Text(CompeteFormatting.formattedScore(row.score, metric: row.metric, distanceUnit: distanceUnit))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.stepInk)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(12)
        .background(row.isCurrentUser ? Color.stepAccent.opacity(0.10) : Color.stepBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var rowSubtitle: String {
        if isSampleRow {
            return "Preview competitor"
        }
        return row.isCurrentUser ? "Your aggregate summary" : "Shared daily summary"
    }
}

struct CompeteMemberRow: View {
    let member: HouseholdMember

    var body: some View {
        HStack(spacing: 12) {
            Text(member.competitor.initials)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(member.isCurrentUser ? Color.stepAccent : Color.stepDistance)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(member.competitor.displayName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.stepInk)
                    if member.isCurrentUser {
                        Text("You")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.stepAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.stepAccent.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                Text("Last updated \(member.lastUpdatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(Color.stepMuted)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

enum CompeteFormatting {
    static func formattedScore(_ score: Double, metric: CompetitionMetric, distanceUnit: DistanceUnit) -> String {
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
                    Button("Cancel") { dismiss() }
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
        case .miles: return value * 1_609.344
        case .kilometers: return value * 1_000
        }
    }
}
