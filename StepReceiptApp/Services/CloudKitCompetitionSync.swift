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
    private static let schemaVersion = 1
    private static let maxEntriesPerBoard = 400
    private static let entryRecordType = "CompetitionEntry"

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
        let localEntries = mergedEntries(entries)
        let remoteRecords = try await fetchEntryRecords(groupHash: groupHash)
        let remoteEntries = mergedEntries(remoteRecords.compactMap(entry(from:)))

        for entry in localEntries {
            let recordName = Self.entryRecordName(groupHash: groupHash, entryID: entry.id)
            let currentRecord = remoteRecords.first { $0.recordID.recordName == recordName }
            try await saveLocalEntry(entry, groupHash: groupHash, existingRecord: currentRecord)
        }

        let savedEntries = mergedEntries(remoteEntries + localEntries)
        return savedEntries
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

    private func fetchEntryRecords(groupHash: String) async throws -> [CKRecord] {
        let query = CKQuery(recordType: Self.entryRecordType, predicate: NSPredicate(format: "groupHash == %@", groupHash))
        var records: [CKRecord] = []

        let firstPage = try await database.records(
            matching: query,
            desiredKeys: nil,
            resultsLimit: Self.maxEntriesPerBoard
        )
        records.append(contentsOf: successfulRecords(from: firstPage.matchResults))

        var cursor = firstPage.queryCursor
        while let currentCursor = cursor, records.count < Self.maxEntriesPerBoard {
            let page = try await database.records(
                continuingMatchFrom: currentCursor,
                desiredKeys: nil,
                resultsLimit: Self.maxEntriesPerBoard - records.count
            )
            records.append(contentsOf: successfulRecords(from: page.matchResults))
            cursor = page.queryCursor
        }

        return records
    }

    private func successfulRecords(from matches: [(CKRecord.ID, Result<CKRecord, Error>)]) -> [CKRecord] {
        matches.compactMap { _, result in
            guard case .success(let record) = result else { return nil }
            return record
        }
    }

    private func saveLocalEntry(
        _ entry: CompetitionEntry,
        groupHash: String,
        existingRecord: CKRecord?
    ) async throws {
        let recordName = Self.entryRecordName(groupHash: groupHash, entryID: entry.id)
        var record = existingRecord ?? CKRecord(
            recordType: Self.entryRecordType,
            recordID: CKRecord.ID(recordName: recordName)
        )

        for _ in 0..<3 {
            update(record: record, groupHash: groupHash, entry: entry)

            do {
                _ = try await database.save(record)
                return
            } catch {
                if let serverRecord = serverChangedRecord(from: error) {
                    record = serverRecord
                    continue
                }
                if isMissingRecord(error) {
                    record = CKRecord(recordType: Self.entryRecordType, recordID: CKRecord.ID(recordName: recordName))
                    continue
                }
                throw error
            }
        }

        throw CloudSyncError.unavailable("Competition entry could not be saved.")
    }

    private func update(record: CKRecord, groupHash: String, entry: CompetitionEntry) {
        record["groupHash"] = groupHash
        record["schemaVersion"] = Self.schemaVersion
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
    }

    private func entry(from record: CKRecord) -> CompetitionEntry? {
        guard
            let competitorIDString = record["competitorID"] as? String,
            let competitorID = UUID(uuidString: competitorIDString),
            let displayName = record["displayName"] as? String,
            let accentHex = record["accentHex"] as? String,
            let dayKey = record["dayKey"] as? String,
            let updatedAt = record["updatedAt"] as? Date
        else {
            return nil
        }

        let initials = record["initials"] as? String
        let competitor = CompetitorProfile(
            id: competitorID,
            displayName: displayName,
            initials: initials,
            accentHex: accentHex
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

    private func intValue(_ value: Any?) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? Int64 { return Int(value) }
        if let value = value as? NSNumber { return value.intValue }
        return 0
    }

    private func doubleValue(_ value: Any?) -> Double {
        if let value = value as? Double { return value }
        if let value = value as? NSNumber { return value.doubleValue }
        return 0
    }

    private func mergedEntries(_ entries: [CompetitionEntry]) -> [CompetitionEntry] {
        var entriesByID: [String: CompetitionEntry] = [:]
        for entry in entries {
            if let existing = entriesByID[entry.id], existing.updatedAt > entry.updatedAt {
                continue
            }
            entriesByID[entry.id] = entry
        }
        return Array(entriesByID.values)
            .sorted {
                if $0.dayKey == $1.dayKey {
                    return $0.competitor.displayName.localizedCaseInsensitiveCompare($1.competitor.displayName) == .orderedAscending
                }
                return $0.dayKey > $1.dayKey
            }
            .prefix(Self.maxEntriesPerBoard)
            .map { $0 }
    }

    private func isMissingRecord(_ error: Error) -> Bool {
        guard let error = error as? CKError else { return false }
        return error.code == .unknownItem
    }

    private func serverChangedRecord(from error: Error) -> CKRecord? {
        guard let error = error as? CKError, error.code == .serverRecordChanged else { return nil }
        return error.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord
    }

    static func groupHash(for inviteCode: String) -> String {
        let normalizedCode = SharedCompetitionSettings.normalizedInviteCode(inviteCode)
        let digest = SHA256.hash(data: Data(normalizedCode.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func boardRecordName(for groupHash: String) -> String {
        "competition-board-\(groupHash)"
    }

    static func entryRecordName(groupHash: String, entryID: String) -> String {
        let digest = SHA256.hash(data: Data("\(groupHash)|\(entryID)".utf8))
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        return "competition-entry-\(hash)"
    }
}

extension CloudKitCompetitionSync: SharedCompetitionSyncing {}
