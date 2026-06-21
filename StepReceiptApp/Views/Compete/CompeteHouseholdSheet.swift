import CloudKit
import SwiftUI
import UIKit

struct CloudKitShareSheet: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        private let dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {}

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {}

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            dismiss()
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            "StrideSlip Household Board"
        }

        func itemThumbnailData(for csc: UICloudSharingController) -> Data? {
            nil
        }
    }
}

struct CompeteHouseholdSheet: View {
    @EnvironmentObject private var repository: ActivityRepository
    @Environment(\.dismiss) private var dismiss

    @State private var inviteShare: CompetitionInviteShare?
    @State private var householdShare: HouseholdCompetitionShare?
    @State private var shareError: String?
    @State private var showLeaveConfirmation = false
    @State private var partnerCodeDraft = ""
    @State private var partnerClipboardError: String?
    @State private var partnerJoinError: String?
    @State private var showSwitchCodeConfirmation = false
    @State private var isSwitchingCode = false
    @State private var showDiagnostics = false
    @State private var ckSharePrepared = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    CompeteSyncStatusRow(
                        state: repository.sharedCompetitionSyncState,
                        canSync: repository.sharedCompetitionSettings.canSync,
                        canPublishEntries: repository.canPublishSharedCompetitionEntries
                    )

                    membersSection
                    codeSection
                    joinPartnerSection
                    actionsSection

                    if let shareError {
                        Text(shareError)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.stepWarning)
                    }
                }
                .padding(16)
            }
            .background(Color.stepBackground)
            .navigationTitle("Household")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showDiagnostics = true
                    } label: {
                        Image(systemName: "stethoscope")
                    }
                    .accessibilityLabel("Compete diagnostics")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showDiagnostics) {
                CompeteDiagnosticsSheet()
                    .environmentObject(repository)
            }
            .sheet(item: $inviteShare) { inviteShare in
                ShareSheet(items: [inviteShare.message])
            }
            .sheet(item: $householdShare) { share in
                CloudKitShareSheet(share: share.share, container: share.container)
            }
            .confirmationDialog(
                "Leave this household board?",
                isPresented: $showLeaveConfirmation,
                titleVisibility: .visible
            ) {
                Button("Leave Board", role: .destructive) {
                    Task {
                        await repository.updateSharedCompetition(isEnabled: false, inviteCode: "")
                        dismiss()
                    }
                }
            } message: {
                Text("Your phone will stop syncing to this board. You can rejoin later with the same code.")
            }
            .confirmationDialog(
                "Switch to partner's board?",
                isPresented: $showSwitchCodeConfirmation,
                titleVisibility: .visible
            ) {
                Button("Switch code") {
                    Task { await switchToPartnerCode() }
                }
            } message: {
                Text("This replaces your current household code and leaves your solo board.")
            }
            .onAppear {
                if partnerCodeDraft.isEmpty, let clipboardCode = CompeteInviteCodeClipboard.normalizedCodeFromClipboard() {
                    partnerCodeDraft = clipboardCode
                }
            }
        }
        .accessibilityIdentifier("compete-household-sheet")
    }

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Members")
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text("\(repository.householdMembers.count)/\(CompetitionBoardPhaseResolver.maxHouseholdMembers)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.stepMuted)
            }

            if repository.householdMembers.isEmpty {
                Text("No members synced yet.")
                    .font(.subheadline)
                    .foregroundStyle(Color.stepMuted)
            } else {
                ForEach(repository.householdMembers) { member in
                    CompeteMemberRow(member: member)
                }
            }
        }
        .metricCard()
    }

    private var codeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your code")
                .font(.subheadline.weight(.bold))
            Text(repository.sharedCompetitionSettings.inviteCode)
                .font(.title2.monospaced().weight(.bold))
                .foregroundStyle(Color.stepInk)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.stepBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityIdentifier("compete-household-your-code")
        }
        .metricCard()
    }

    private var joinPartnerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Join partner's board")
                .font(.subheadline.weight(.bold))

            TextField("Partner's code", text: $partnerCodeDraft)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.body.monospaced().weight(.semibold))
                .padding(12)
                .background(Color.stepBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityIdentifier("compete-household-partner-code")

            HStack(spacing: 10) {
                Button("Paste") {
                    pastePartnerCode()
                }
                .buttonStyle(.bordered)
                .tint(.stepDistance)

                Button {
                    if repository.sharedCompetitionSettings.canSync {
                        showSwitchCodeConfirmation = true
                    } else {
                        Task { await switchToPartnerCode() }
                    }
                } label: {
                    if isSwitchingCode {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Switch to this code")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.stepAccent)
                .disabled(switchCodeDisabled || isSwitchingCode)
                .accessibilityIdentifier("compete-household-switch-code")
            }
            .controlSize(.large)

            if let partnerClipboardError {
                Text(partnerClipboardError)
                    .font(.caption)
                    .foregroundStyle(Color.stepWarning)
            }

            if let partnerJoinError {
                Text(partnerJoinError)
                    .font(.caption)
                    .foregroundStyle(Color.stepWarning)
            }
        }
        .metricCard()
    }

    private var switchCodeDisabled: Bool {
        SharedCompetitionSettings.normalizedInviteCode(partnerCodeDraft).isEmpty
    }

    private func pastePartnerCode() {
        guard let normalized = CompeteInviteCodeClipboard.normalizedCodeFromClipboard() else {
            partnerClipboardError = "No code on clipboard."
            return
        }
        partnerClipboardError = nil
        partnerCodeDraft = normalized
    }

    private func switchToPartnerCode() async {
        partnerJoinError = nil
        isSwitchingCode = true
        defer { isSwitchingCode = false }

        let displayName = repository.preferences.displayName
        await repository.updateSharedCompetitionWithProfile(
            isEnabled: true,
            inviteCode: partnerCodeDraft,
            displayName: displayName
        )

        if case .synced = repository.sharedCompetitionSyncState {
            return
        }

        await repository.syncSharedCompetition(force: true)

        if case .unavailable(let reason) = repository.sharedCompetitionSyncState {
            partnerJoinError = CompetitionSyncPresentation.shortIssue(reason)
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 10) {
            Button {
                inviteShare = CompetitionInviteShare(code: repository.sharedCompetitionSettings.inviteCode)
            } label: {
                Label("Invite partner", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.stepAccent)
            .accessibilityIdentifier("compete-invite-partner-primary")

            if repository.isCloudKitCompetitionAvailable {
                Button {
                    Task { await prepareCloudShare() }
                } label: {
                    Label("Invite via iCloud", systemImage: "person.crop.circle.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.stepDistance)
                .accessibilityIdentifier("compete-icloud-invite")

                if ckSharePrepared {
                    Text("Partner must accept the invite in Messages, then StrideSlip opens to confirm joining.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.stepMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                UIPasteboard.general.string = repository.sharedCompetitionSettings.inviteCode
            } label: {
                Label("Copy code", systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                Task { await repository.syncSharedCompetition(force: true) }
            } label: {
                Label("Refresh board", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(repository.sharedCompetitionSyncState == .syncing)

            Button(role: .destructive) {
                showLeaveConfirmation = true
            } label: {
                Label("Leave board", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .controlSize(.large)
    }

    private func prepareCloudShare() async {
        shareError = nil
        do {
            householdShare = try await repository.prepareHouseholdCompetitionShare()
            ckSharePrepared = true
        } catch {
            shareError = CloudKitCompetitionSync.friendlySyncMessage(for: error)
        }
    }
}
