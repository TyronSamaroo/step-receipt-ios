import SwiftUI
import UIKit

enum CompeteSetupMode {
    case create
    case join
}

struct CompeteSetupWizardView: View {
    @EnvironmentObject private var repository: ActivityRepository
    @Environment(\.dismiss) private var dismiss

    let mode: CompeteSetupMode

    @State private var step = 0
    @State private var profileNameDraft = ""
    @State private var inviteCodeDraft = ""
    @State private var clipboardError: String?
    @State private var inviteShare: CompetitionInviteShare?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                progressHeader

                switch step {
                case 0:
                    nameStep
                case 1:
                    codeStep
                default:
                    syncStep
                }

                Spacer(minLength: 0)

                wizardActions
            }
            .padding(20)
            .background(Color.stepBackground)
            .navigationTitle(mode == .create ? "Start Board" : "Join Board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: $inviteShare) { inviteShare in
                ShareSheet(items: [inviteShare.message])
            }
            .onAppear {
                profileNameDraft = repository.preferences.displayName
                if mode == .create, inviteCodeDraft.isEmpty {
                    inviteCodeDraft = repository.generatedSharedCompetitionInviteCode()
                } else {
                    inviteCodeDraft = repository.sharedCompetitionSettings.inviteCode
                }
            }
        }
    }

    private var progressHeader: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? Color.stepAccent : Color.stepMuted.opacity(0.25))
                    .frame(height: 4)
            }
        }
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your board name")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.stepInk)
            Text("This is how you'll appear on the household leaderboard.")
                .font(.subheadline)
                .foregroundStyle(Color.stepMuted)

            TextField("Board name", text: $profileNameDraft)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(14)
                .background(Color.stepSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var codeStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(mode == .create ? "Household code" : "Paste invite code")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.stepInk)
            Text(mode == .create
                 ? "Share this code with your partner. Both phones use the same code."
                 : "Paste the code from your partner's invite message.")
                .font(.subheadline)
                .foregroundStyle(Color.stepMuted)

            TextField("Code", text: $inviteCodeDraft)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.title3.monospaced().weight(.bold))
                .padding(14)
                .background(Color.stepSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            if mode == .create {
                Button("Generate new code") {
                    inviteCodeDraft = repository.generatedSharedCompetitionInviteCode()
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.stepAccent)
            } else {
                Button("Paste from clipboard") {
                    pasteInviteCode()
                }
                .buttonStyle(.bordered)
                .tint(.stepDistance)
            }

            if let clipboardError {
                Text(clipboardError)
                    .font(.caption)
                    .foregroundStyle(Color.stepWarning)
            }
        }
    }

    private var syncStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sync your row")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.stepInk)
            Text("We'll publish your daily totals to the shared board. Pull to refresh anytime.")
                .font(.subheadline)
                .foregroundStyle(Color.stepMuted)

            CompeteSyncStatusRow(
                state: repository.sharedCompetitionSyncState,
                canSync: !SharedCompetitionSettings.normalizedInviteCode(inviteCodeDraft).isEmpty,
                canPublishEntries: repository.canPublishSharedCompetitionEntries
            )

            if !repository.isCloudKitCompetitionAvailable {
                CompeteAttentionCard(
                    title: "CloudKit unavailable in this build",
                    detail: "Install the production StrideSlip bundle to sync a household board.",
                    systemImage: "icloud.slash"
                )
            } else if !repository.canPublishSharedCompetitionEntries {
                CompeteAttentionCard(
                    title: "Connect Apple Health",
                    detail: "Grant Health access so your daily totals can publish to the board.",
                    systemImage: StepReceiptSymbol.health
                )
            }
        }
    }

    private var wizardActions: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button("Back") {
                    step -= 1
                }
                .buttonStyle(.bordered)
            }

            Button(step < 2 ? "Continue" : "Sync board") {
                if step < 2 {
                    step += 1
                } else {
                    Task { await syncBoard() }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.stepAccent)
            .frame(maxWidth: .infinity)
            .disabled(continueDisabled)
        }
        .controlSize(.large)
    }

    private var continueDisabled: Bool {
        switch step {
        case 0:
            profileNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 1:
            SharedCompetitionSettings.normalizedInviteCode(inviteCodeDraft).isEmpty
        default:
            repository.sharedCompetitionSyncState == .syncing
        }
    }

    private func pasteInviteCode() {
        guard let normalized = normalizedInviteCodeFromClipboard() else {
            clipboardError = "No code on clipboard."
            return
        }
        clipboardError = nil
        inviteCodeDraft = normalized
    }

    private func normalizedInviteCodeFromClipboard() -> String? {
        guard let value = UIPasteboard.general.string else { return nil }
        return SharedCompetitionSettings.normalizedInviteCodeCandidates(from: value).first
    }

    private func syncBoard() async {
        await repository.updateSharedCompetitionWithProfile(
            isEnabled: true,
            inviteCode: inviteCodeDraft,
            displayName: profileNameDraft
        )

        if case .synced = repository.sharedCompetitionSyncState, mode == .create {
            inviteShare = CompetitionInviteShare(code: repository.sharedCompetitionSettings.inviteCode)
        }

        if case .synced = repository.sharedCompetitionSyncState {
            dismiss()
        }
    }
}
