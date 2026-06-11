import Foundation

struct DisabledCloudKitSummarySync: CloudKitSummarySyncing {
    let reason: String

    init(reason: String = "CloudKit is disabled for this local personal-team build.") {
        self.reason = reason
    }

    func status() async -> CloudSyncState {
        .unavailable(reason)
    }

    func sync(records: [SyncedSummaryRecord]) async throws {
        throw CloudSyncError.unavailable(reason)
    }
}

struct DisabledSharedCompetitionSync: SharedCompetitionSyncing {
    let reason: String

    init(reason: String = "Household sync requires the production CloudKit build.") {
        self.reason = reason
    }

    func sync(entries: [CompetitionEntry], inviteCode: String) async throws -> [CompetitionEntry] {
        throw CloudSyncError.unavailable(reason)
    }
}
