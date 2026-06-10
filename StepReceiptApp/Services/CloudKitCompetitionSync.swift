import CloudKit
import CryptoKit
import Foundation

enum CompetitionSyncState: Equatable, Sendable {
    case off
    case idle
    case syncing
    case synced(Date)
    case unavailable(String)
}

protocol SharedCompetitionSyncing: Sendable {
    func sync(entries: [CompetitionEntry], inviteCode: String) async throws -> [CompetitionEntry]
}

final class CloudKitCompetitionSync: @unchecked Sendable {
    private let container: CKContainer
    private let database: CKDatabase

    init(containerIdentifier: String = "iCloud.com.tyronsamaroo.stepreceipt") {
        container = CKContainer(identifier: containerIdentifier)
        database = container.publicCloudDatabase
    }

    func sync(entries: [CompetitionEntry], inviteCode: String) async throws -> [CompetitionEntry] {
        let normalizedCode = SharedCompetitionSettings.normalizedInviteCode(inviteCode)
        guard !normalizedCode.isEmpty else { return [] }

        try await requireAvailableAccount()

        let groupHash = Self.groupHash(for: normalizedCode)
        if !entries.isEmpty {
            let records = entries.map { makeRecord(from: $0, groupHash: groupHash) }
            _ = try await database.modifyRecords(
                saving: records,
                deleting: [],
                savePolicy: .changedKeys,
                atomically: false
            )
        }

        return try await fetchEntries(groupHash: groupHash)
    }

    private func requireAvailableAccount() async throws {
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                return
            case .noAccount:
                throw CloudSyncError.unavailable("iCloud is not signed in.")
            case .restricted:
                throw CloudSyncError.unavailable("iCloud is restricted on this device.")
            case .couldNotDetermine:
                throw CloudSyncError.unavailable("iCloud status could not be determined.")
            case .temporarilyUnavailable:
                throw CloudSyncError.unavailable("iCloud is temporarily unavailable.")
            @unknown default:
                throw CloudSyncError.unavailable("iCloud returned an unknown status.")
            }
        } catch let error as CloudSyncError {
            throw error
        } catch {
            throw CloudSyncError.unavailable(error.localizedDescription)
        }
    }

    private func makeRecord(from entry: CompetitionEntry, groupHash: String) -> CKRecord {
        let recordName = "\(groupHash)-\(entry.competitor.id.uuidString)-\(entry.dayKey)"
        let record = CKRecord(recordType: "CompetitionDailyEntry", recordID: CKRecord.ID(recordName: recordName))
        record["groupHash"] = groupHash
        record["competitorID"] = entry.competitor.id.uuidString
        record["displayName"] = entry.competitor.displayName
        record["initials"] = entry.competitor.initials
        record["accentHex"] = entry.competitor.accentHex
        record["dayKey"] = entry.dayKey
        record["steps"] = entry.steps
        record["distanceMeters"] = entry.distanceMeters
        record["activeEnergyKilocalories"] = entry.activeEnergyKilocalories
        record["workoutMinutes"] = entry.workoutMinutes
        record["updatedAt"] = entry.updatedAt
        return record
    }

    private func fetchEntries(groupHash: String) async throws -> [CompetitionEntry] {
        let query = CKQuery(
            recordType: "CompetitionDailyEntry",
            predicate: NSPredicate(format: "groupHash == %@", groupHash)
        )

        var fetchedRecords: [CKRecord] = []
        let initial = try await database.records(matching: query, resultsLimit: CKQueryOperation.maximumResults)
        fetchedRecords.append(contentsOf: try records(from: initial.matchResults))

        var cursor = initial.queryCursor
        while let currentCursor = cursor {
            let page = try await database.records(continuingMatchFrom: currentCursor, resultsLimit: CKQueryOperation.maximumResults)
            fetchedRecords.append(contentsOf: try records(from: page.matchResults))
            cursor = page.queryCursor
        }

        return fetchedRecords
            .compactMap(entry)
            .sorted {
                if $0.dayKey == $1.dayKey {
                    return $0.competitor.displayName.localizedCaseInsensitiveCompare($1.competitor.displayName) == .orderedAscending
                }
                return $0.dayKey > $1.dayKey
            }
    }

    private func records(from results: [(CKRecord.ID, Result<CKRecord, Error>)]) throws -> [CKRecord] {
        try results.map { _, result in
            try result.get()
        }
    }

    private func entry(from record: CKRecord) -> CompetitionEntry? {
        guard
            let competitorID = stringValue(record["competitorID"]).flatMap(UUID.init(uuidString:)),
            let displayName = stringValue(record["displayName"]),
            let dayKey = stringValue(record["dayKey"]),
            let updatedAt = record["updatedAt"] as? Date
        else {
            return nil
        }

        let competitor = CompetitorProfile(
            id: competitorID,
            displayName: displayName,
            initials: stringValue(record["initials"]),
            accentHex: stringValue(record["accentHex"]) ?? "#3364C3"
        )

        return CompetitionEntry(
            competitor: competitor,
            dayKey: dayKey,
            steps: intValue(record["steps"]),
            distanceMeters: doubleValue(record["distanceMeters"]),
            activeEnergyKilocalories: doubleValue(record["activeEnergyKilocalories"]),
            workoutMinutes: doubleValue(record["workoutMinutes"]),
            updatedAt: updatedAt
        )
    }

    private func stringValue(_ value: CKRecordValue?) -> String? {
        value as? String
    }

    private func intValue(_ value: CKRecordValue?) -> Int {
        if let value = value as? Int {
            return value
        }
        return (value as? NSNumber)?.intValue ?? 0
    }

    private func doubleValue(_ value: CKRecordValue?) -> Double {
        if let value = value as? Double {
            return value
        }
        return (value as? NSNumber)?.doubleValue ?? 0
    }

    static func groupHash(for inviteCode: String) -> String {
        let normalizedCode = SharedCompetitionSettings.normalizedInviteCode(inviteCode)
        let digest = SHA256.hash(data: Data(normalizedCode.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

extension CloudKitCompetitionSync: SharedCompetitionSyncing {}
