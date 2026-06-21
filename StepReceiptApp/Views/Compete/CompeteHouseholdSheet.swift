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
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
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
            Text("Household code")
                .font(.subheadline.weight(.bold))
            Text(repository.sharedCompetitionSettings.inviteCode)
                .font(.title2.monospaced().weight(.bold))
                .foregroundStyle(Color.stepInk)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.stepBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .metricCard()
    }

    private var actionsSection: some View {
        VStack(spacing: 10) {
            Button {
                inviteShare = CompetitionInviteShare(code: repository.sharedCompetitionSettings.inviteCode)
            } label: {
                Label("Share code", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.stepAccent)

            Button {
                UIPasteboard.general.string = repository.sharedCompetitionSettings.inviteCode
            } label: {
                Label("Copy code", systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

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
            }

            Button {
                Task { await repository.syncSharedCompetition() }
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
        } catch {
            shareError = CloudKitCompetitionSync.friendlySyncMessage(for: error)
        }
    }
}
