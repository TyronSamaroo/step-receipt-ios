import SwiftUI

struct CompetitionView: View {
    @EnvironmentObject private var repository: ActivityRepository
    @State private var setupMode: CompeteSetupMode?
    @State private var isPresentingHouseholdSheet = false
    @State private var isPresentingCheckIn = false
    @State private var inviteShare: CompetitionInviteShare?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch repository.competeBoardPhase {
                    case .setup:
                        CompeteWelcomeView(
                            onStartBoard: { setupMode = .create },
                            onJoinBoard: { setupMode = .join }
                        )
                    case .waitingForPartner, .active, .needsAttention:
                        if let receipt = repository.competitionReceipt {
                            CompeteLeaderboardView(
                                receipt: receipt,
                                showsSampleBoard: repository.isShowingSampleCompetitionBoard,
                                phase: repository.competeBoardPhase,
                                onInvitePartner: shareInviteCode
                            )
                        } else {
                            ProgressView("Loading board")
                                .frame(maxWidth: .infinity, minHeight: 240)
                        }
                    }
                }
                .padding(repository.competeBoardPhase == .setup ? 0 : 16)
            }
            .refreshable {
                await syncSharedBoardIfNeeded()
            }
            .safeAreaPadding(.bottom, 84)
            .background(Color.stepBackground)
            .navigationTitle("Compete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if repository.sharedCompetitionSettings.canSync {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            isPresentingHouseholdSheet = true
                        } label: {
                            Image(systemName: "person.2.circle")
                        }
                        .accessibilityLabel("Household settings")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            isPresentingCheckIn = true
                        } label: {
                            Label("Offline check-in", systemImage: "plus.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Compete options")
                }
            }
            .sheet(item: $setupMode) { mode in
                CompeteSetupWizardView(mode: mode)
                    .environmentObject(repository)
            }
            .sheet(isPresented: $isPresentingHouseholdSheet) {
                CompeteHouseholdSheet()
                    .environmentObject(repository)
            }
            .sheet(isPresented: $isPresentingCheckIn) {
                CompetitionCheckInSheet()
                    .environmentObject(repository)
            }
            .sheet(item: $inviteShare) { inviteShare in
                ShareSheet(items: [inviteShare.message])
            }
            .task {
                await syncSharedBoardIfNeeded()
            }
        }
    }

    private func shareInviteCode() {
        guard repository.sharedCompetitionSettings.canSync else { return }
        inviteShare = CompetitionInviteShare(code: repository.sharedCompetitionSettings.inviteCode)
    }

    private func syncSharedBoardIfNeeded() async {
        guard repository.sharedCompetitionSettings.canSync,
              repository.sharedCompetitionSyncState != .syncing else { return }
        await repository.syncSharedCompetition()
    }
}

extension CompeteSetupMode: Identifiable {
    var id: Self { self }
}
