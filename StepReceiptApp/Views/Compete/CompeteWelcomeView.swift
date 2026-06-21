import SwiftUI

struct CompeteWelcomeView: View {
    @EnvironmentObject private var repository: ActivityRepository

    let onStartBoard: () -> Void
    let onJoinBoard: () -> Void

    @State private var inviteCodeDraft = ""
    @State private var profileNameDraft = ""
    @State private var clipboardError: String?
    @State private var joinError: String?
    @State private var isJoining = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)

            VStack(spacing: 14) {
                Image(systemName: StepReceiptSymbol.competitionTab)
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(Color.stepAccent)
                    .frame(width: 88, height: 88)
                    .background(
                        LinearGradient(
                            colors: [Color.stepAccent.opacity(0.18), Color.stepEnergy.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                Text("Compete together")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.stepInk)
                    .multilineTextAlignment(.center)

                Text("Start a household board for you and your partner. Only daily totals sync — steps, distance, burn, and workout minutes.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.stepMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)

            VStack(spacing: 12) {
                Button(action: onStartBoard) {
                    Label("Start a household board", systemImage: "person.2.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.stepAccent)
                .controlSize(.large)
                .accessibilityIdentifier("compete-welcome-start")

                Button(action: onJoinBoard) {
                    Label("Join with code", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.stepDistance)
                .controlSize(.large)
                .accessibilityIdentifier("compete-welcome-join")
            }

            quickJoinSection

            Label("Privacy-safe: aggregate daily totals only", systemImage: "lock.shield")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.stepMuted)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(20)
        .accessibilityIdentifier("compete-welcome-screen")
        .accessibilityElement(children: .contain)
        .onAppear {
            if profileNameDraft.isEmpty {
                profileNameDraft = repository.preferences.displayName
            }
            if inviteCodeDraft.isEmpty, let clipboardCode = CompeteInviteCodeClipboard.normalizedCodeFromClipboard() {
                inviteCodeDraft = clipboardCode
            }
        }
    }

    private var quickJoinSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Have a code?")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.stepInk)

            TextField("Household code", text: $inviteCodeDraft)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.body.monospaced().weight(.semibold))
                .padding(12)
                .background(Color.stepSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityIdentifier("compete-welcome-join-code")

            TextField("Board name", text: $profileNameDraft)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(12)
                .background(Color.stepSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityIdentifier("compete-welcome-join-name")

            HStack(spacing: 10) {
                Button("Paste") {
                    pasteInviteCode()
                }
                .buttonStyle(.bordered)
                .tint(.stepDistance)

                Button {
                    Task { await joinBoard() }
                } label: {
                    if isJoining {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Join board")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.stepAccent)
                .disabled(joinDisabled || isJoining)
                .accessibilityIdentifier("compete-welcome-join-submit")
            }
            .controlSize(.large)

            if let clipboardError {
                Text(clipboardError)
                    .font(.caption)
                    .foregroundStyle(Color.stepWarning)
            }

            if let joinError {
                Text(joinError)
                    .font(.caption)
                    .foregroundStyle(Color.stepWarning)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.stepSurface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityIdentifier("compete-welcome-quick-join")
    }

    private var joinDisabled: Bool {
        SharedCompetitionSettings.normalizedInviteCode(inviteCodeDraft).isEmpty
            || profileNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func pasteInviteCode() {
        guard let normalized = CompeteInviteCodeClipboard.normalizedCodeFromClipboard() else {
            clipboardError = "No code on clipboard."
            return
        }
        clipboardError = nil
        inviteCodeDraft = normalized
    }

    private func joinBoard() async {
        joinError = nil
        isJoining = true
        defer { isJoining = false }

        await repository.updateSharedCompetitionWithProfile(
            isEnabled: true,
            inviteCode: inviteCodeDraft,
            displayName: profileNameDraft
        )

        if case .synced = repository.sharedCompetitionSyncState {
            return
        }

        await repository.syncSharedCompetition()

        if case .unavailable(let reason) = repository.sharedCompetitionSyncState {
            joinError = CompetitionSyncPresentation.shortIssue(reason)
        }
    }
}
