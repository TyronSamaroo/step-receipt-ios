@preconcurrency import AppIntents
import Foundation

struct SyncHouseholdBoardIntent: AppIntent {
    static let title: LocalizedStringResource = "Sync Household Board"
    static let description = IntentDescription("Syncs your household compete leaderboard when a board is active.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let repository = await MainActor.run { StepReceiptAppIntentsSupport.repository }
        guard let repository else {
            throw StepReceiptIntentError.repositoryUnavailable
        }

        let canSync = await MainActor.run { repository.sharedCompetitionSettings.canSync }
        guard canSync else {
            throw StepReceiptIntentError.boardDisabled
        }

        await repository.syncSharedCompetition()

        let detail = await MainActor.run {
            CompetitionSyncPresentation.statusTitle(for: repository.sharedCompetitionSyncState)
        }
        return .result(dialog: "Household board sync finished: \(detail).")
    }
}
