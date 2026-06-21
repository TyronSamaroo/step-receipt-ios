import AppIntents
import Foundation

struct SyncHouseholdBoardIntent: AppIntent {
    static var title: LocalizedStringResource = "Sync Household Board"
    static var description = IntentDescription("Syncs your household compete leaderboard when a board is active.")
    static var openAppWhenRun: Bool = false

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
