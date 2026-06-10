import CloudKit
import Foundation

enum CloudSyncState: Equatable, Sendable {
    case unknown
    case available
    case unavailable(String)
}

enum CloudSyncError: LocalizedError, Sendable {
    case unavailable(String)
    case missingSavedRecord(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let reason):
            return reason
        case .missingSavedRecord(let dayKey):
            return "CloudKit did not return saved summary record \(dayKey)."
        }
    }
}

final class CloudKitSummarySync: @unchecked Sendable {
    private let container: CKContainer
    private let database: CKDatabase

    init(containerIdentifier: String = "iCloud.com.tyronsamaroo.stepreceipt") {
        container = CKContainer(identifier: containerIdentifier)
        database = container.privateCloudDatabase
    }

    func status() async -> CloudSyncState {
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                return .available
            case .noAccount:
                return .unavailable("iCloud is not signed in.")
            case .restricted:
                return .unavailable("iCloud is restricted on this device.")
            case .couldNotDetermine:
                return .unavailable("iCloud status could not be determined.")
            case .temporarilyUnavailable:
                return .unavailable("iCloud is temporarily unavailable.")
            @unknown default:
                return .unavailable("iCloud returned an unknown status.")
            }
        } catch {
            return .unavailable(error.localizedDescription)
        }
    }

    func sync(record: SyncedSummaryRecord) async throws {
        try await sync(records: [record])
    }

    func sync(records: [SyncedSummaryRecord]) async throws {
        guard !records.isEmpty else { return }

        let currentStatus = await status()
        guard case .available = currentStatus else {
            if case .unavailable(let reason) = currentStatus {
                throw CloudSyncError.unavailable(reason)
            }
            throw CloudSyncError.unavailable("iCloud status is unknown.")
        }

        let ckRecords = records.map(makeRecord)
        let result = try await database.modifyRecords(
            saving: ckRecords,
            deleting: [],
            savePolicy: .changedKeys,
            atomically: false
        )

        for record in records {
            let recordID = CKRecord.ID(recordName: record.dayKey)
            guard let savedRecord = result.saveResults[recordID] else {
                throw CloudSyncError.missingSavedRecord(record.dayKey)
            }
            _ = try savedRecord.get()
        }
    }

    private func makeRecord(from record: SyncedSummaryRecord) -> CKRecord {
        let ckRecord = CKRecord(recordType: "DailyActivitySummary", recordID: CKRecord.ID(recordName: record.dayKey))
        ckRecord["dayKey"] = record.dayKey
        ckRecord["dateStart"] = record.dateStart
        ckRecord["steps"] = record.steps
        ckRecord["distanceMeters"] = record.distanceMeters
        ckRecord["activeEnergyKilocalories"] = record.activeEnergyKilocalories
        ckRecord["flightsClimbed"] = record.flightsClimbed
        ckRecord["workoutMinutes"] = record.workoutMinutes
        ckRecord["workoutCount"] = record.workoutCount
        ckRecord["stepGoal"] = record.stepGoal
        ckRecord["updatedAt"] = record.updatedAt
        return ckRecord
    }
}
