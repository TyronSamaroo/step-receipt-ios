import SwiftUI

struct CompeteJoinConfirmationSheet: View {
    @EnvironmentObject private var repository: ActivityRepository
    @Environment(\.dismiss) private var dismiss

    let request: CompeteJoinRequest

    @State private var displayName = ""
    @State private var joinError: String?
    @State private var isJoining = false
    @State private var showReplaceConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                header

                TextField("Board name", text: $displayName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(Color.stepSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityIdentifier("compete-join-confirm-name")

                if let joinError {
                    Text(joinError)
                        .font(.caption)
                        .foregroundStyle(Color.stepWarning)
                }

                Spacer(minLength: 0)

                HStack(spacing: 12) {
                    Button("Cancel") {
                        repository.dismissPendingCompeteJoin()
                        dismiss()
                    }
                    .buttonStyle(.bordered)

                    Button {
                        attemptJoin()
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
                    .accessibilityIdentifier("compete-join-confirm-submit")
                }
                .controlSize(.large)
            }
            .padding(20)
            .background(Color.stepBackground)
            .navigationTitle("Join household board?")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "Replace current board?",
                isPresented: $showReplaceConfirmation,
                titleVisibility: .visible
            ) {
                Button("Join new board") {
                    Task { await performJoin() }
                }
            } message: {
                Text("This replaces your current board code. You'll leave your solo board.")
            }
            .onAppear {
                if displayName.isEmpty {
                    displayName = repository.preferences.displayName
                }
            }
        }
        .accessibilityIdentifier("compete-join-confirmation-sheet")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let ownerName = request.ownerDisplayName, !ownerName.isEmpty {
                Text("\(ownerName) invited you to their household board.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.stepMuted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(sourceDescription)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.stepMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Text("Code")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.stepMuted)
                Text("…\(request.codeHint)")
                    .font(.title3.monospaced().weight(.bold))
                    .foregroundStyle(Color.stepInk)
                    .accessibilityIdentifier("compete-join-confirm-code-hint")
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.stepSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var sourceDescription: String {
        switch request.source {
        case .deepLink:
            "Tap the invite link to join this household board."
        case .cloudKitShare:
            "Accept the iCloud invite to join this household board."
        }
    }

    private var joinDisabled: Bool {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func attemptJoin() {
        if request.requiresReplaceConfirmation(
            currentInviteCode: repository.sharedCompetitionSettings.inviteCode,
            boardEnabled: repository.sharedCompetitionSettings.canSync
        ) {
            showReplaceConfirmation = true
        } else {
            Task { await performJoin() }
        }
    }

    private func performJoin() async {
        joinError = nil
        isJoining = true
        defer { isJoining = false }

        await repository.confirmPendingCompeteJoin(displayName: displayName)

        if case .unavailable(let reason) = repository.sharedCompetitionSyncState {
            joinError = CompetitionSyncPresentation.shortIssue(reason)
            return
        }

        dismiss()
    }
}
