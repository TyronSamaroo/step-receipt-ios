import SwiftUI
import UIKit

struct CompeteLeaderboardView: View {
    @EnvironmentObject private var repository: ActivityRepository

    let receipt: CompetitionReceipt
    let showsSampleBoard: Bool
    let phase: CompeteBoardPhase
    let onInvitePartner: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsSampleBoard {
                CompeteSampleBanner()
            }

            attentionContent

            if phase == .waitingForPartner {
                invitePartnerCard
            }

            controls

            CompetitionSummaryCard(
                receipt: receipt,
                distanceUnit: repository.preferences.distanceUnit,
                showsSampleLabel: showsSampleBoard
            )

            leaderboardCard

            privacyNote
        }
        .accessibilityIdentifier("compete-leaderboard")
    }

    @ViewBuilder
    private var attentionContent: some View {
        if phase == .needsAttention {
            if !repository.isCloudKitCompetitionAvailable {
                CompeteAttentionCard(
                    title: "Production build required",
                    detail: "Household sync needs the production StrideSlip app with iCloud enabled.",
                    systemImage: "icloud.slash"
                )
            } else if case .unavailable(let reason) = repository.sharedCompetitionSyncState {
                CompeteAttentionCard(
                    title: "Sync needs attention",
                    detail: CompetitionSyncPresentation.shortIssue(reason),
                    systemImage: "exclamationmark.triangle.fill"
                )
            } else if !repository.canPublishSharedCompetitionEntries {
                CompeteAttentionCard(
                    title: "Connect Apple Health",
                    detail: "Your row can't publish until Health access is granted.",
                    systemImage: StepReceiptSymbol.health
                )
            }
        }
    }

    private var invitePartnerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Waiting for your partner", systemImage: "heart.fill")
                .font(.headline)
                .foregroundStyle(Color.stepInk)

            Text("Share your household code so they can join and sync their daily totals.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.stepMuted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Text(repository.sharedCompetitionSettings.inviteCode)
                    .font(.title3.monospaced().weight(.bold))
                    .foregroundStyle(Color.stepInk)
                    .accessibilityIdentifier("compete-waiting-household-code")

                Spacer(minLength: 0)

                Button {
                    UIPasteboard.general.string = repository.sharedCompetitionSettings.inviteCode
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption.weight(.bold))
                }
                .buttonStyle(.bordered)
                .tint(.stepDistance)
                .accessibilityIdentifier("compete-waiting-copy-code")
            }
            .padding(12)
            .background(Color.stepBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text("Partner: Compete → Join with code → paste this code")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.stepMuted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("compete-waiting-partner-instructions")

            Button(action: onInvitePartner) {
                Label("Invite partner", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.stepAccent)
        }
        .metricCard()
        .accessibilityIdentifier("compete-invite-partner-card")
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
            .pickerStyle(.segmented)
        }
        .compactMetricCard()
    }

    private var leaderboardCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Leaderboard")
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text(receipt.window.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.stepMuted)
            }

            if receipt.rows.isEmpty {
                Text("No scores yet for this window. Sync after activity is logged.")
                    .font(.subheadline)
                    .foregroundStyle(Color.stepMuted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(receipt.rows) { row in
                    LeaderboardRowView(
                        row: row,
                        distanceUnit: repository.preferences.distanceUnit,
                        isSampleRow: showsSampleBoard && !row.isCurrentUser
                    )
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
            Text("Competition uses daily aggregate totals only. Raw HealthKit samples, hourly buckets, workout details, and source identifiers stay on-device.")
                .font(.footnote)
                .foregroundStyle(Color.stepMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .metricCard()
    }
}
