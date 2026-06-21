import SwiftUI
import UIKit

struct CompeteDiagnosticsSheet: View {
    @EnvironmentObject private var repository: ActivityRepository
    @Environment(\.dismiss) private var dismiss

    @State private var diagnostics = CompetitionSyncDiagnostics(
        boardEnabled: false,
        inviteCodeHint: nil,
        memberCount: 0,
        remoteEntryCount: 0,
        lastSyncState: "Loading",
        lastSyncDetail: "Checking sync status…",
        lastSyncedAt: nil,
        boardRecordHashSuffix: nil,
        cloudKitCompetitionAvailable: false
    )
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isLoading {
                        ProgressView("Checking iCloud and sync…")
                            .frame(maxWidth: .infinity, minHeight: 120)
                    } else {
                        diagnosticsContent
                    }
                }
                .padding(16)
            }
            .background(Color.stepBackground)
            .navigationTitle("Compete Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Copy") {
                        UIPasteboard.general.string = diagnostics.textLines.joined(separator: "\n")
                    }
                    .accessibilityIdentifier("compete-diagnostics-copy")
                }
            }
            .task {
                await refreshDiagnostics()
            }
        }
        .accessibilityIdentifier("compete-diagnostics-sheet")
    }

    private var diagnosticsContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            CompeteSyncStatusRow(
                state: repository.sharedCompetitionSyncState,
                canSync: repository.sharedCompetitionSettings.canSync,
                canPublishEntries: repository.canPublishSharedCompetitionEntries
            )

            if diagnostics.schemaLikelyMissing {
                CompeteAttentionCard(
                    title: "CloudKit schema may be missing",
                    detail: "Deploy HouseholdCompetitionBoard and CompetitionEntry in CloudKit Dashboard. See Docs/CloudKitCompetitionSchema.md.",
                    systemImage: "exclamationmark.triangle.fill"
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(diagnostics.textLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.stepInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
            .background(Color.stepSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button {
                Task {
                    await repository.syncSharedCompetition()
                    await refreshDiagnostics()
                }
            } label: {
                Label("Retry sync", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.stepAccent)
            .controlSize(.large)
            .disabled(repository.sharedCompetitionSyncState == .syncing)
        }
    }

    private func refreshDiagnostics() async {
        isLoading = true
        defer { isLoading = false }
        diagnostics = await repository.enrichedCompetitionSyncDiagnostics()
    }
}
