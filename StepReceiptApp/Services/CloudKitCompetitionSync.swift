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

struct HouseholdCompetitionShare: Identifiable {
    var id: CKRecord.ID { share.recordID }

    let share: CKShare
    let container: CKContainer
}

final class CloudKitCompetitionSync: @unchecked Sendable {
    private static let schemaVersion = 1
    private static let maxEntriesPerBoard = 400
    private static let entryRecordType = "CompetitionEntry"
    private static let shareZoneName = "HouseholdCompetition"
    private static let boardRecordType = "HouseholdCompetitionBoard"

    private let container: CKContainer
    private let database: CKDatabase
    private let privateDatabase: CKDatabase

    init(containerIdentifier: String = "iCloud.com.tyronsamaroo.stepreceipt") {
        container = CKContainer(identifier: containerIdentifier)
        database = container.publicCloudDatabase
        privateDatabase = container.privateCloudDatabase
    }

    func sync(entries: [CompetitionEntry], inviteCode: String) async throws -> [CompetitionEntry] {
        let normalizedCode = SharedCompetitionSettings.normalizedInviteCode(inviteCode)
        guard !normalizedCode.isEmpty else { return [] }

        try await requireAvailableAccount()

        let groupHash = Self.groupHash(for: normalizedCode)
        let localEntries = mergedEntries(entries)
        let boardRecord = try await loadOrCreatePublicBoardRecord(groupHash: groupHash, inviteCode: normalizedCode)
        let knownEntryNames = entryRecordNames(from: boardRecord)
        let localEntryNames = localEntries.map { Self.entryRecordName(groupHash: groupHash, entryID: $0.id) }
        let entryNamesToFetch = Array(Set(knownEntryNames).union(localEntryNames)).sorted()
        let remoteRecords = try await fetchEntryRecords(recordNames: entryNamesToFetch)
        let remoteEntries = mergedEntries(remoteRecords.compactMap(entry(from:)))

        for entry in localEntries {
            let recordName = Self.entryRecordName(groupHash: groupHash, entryID: entry.id)
            let currentRecord = remoteRecords.first { $0.recordID.recordName == recordName }
            try await saveLocalEntry(entry, groupHash: groupHash, existingRecord: currentRecord)
        }

        let savedEntryNames = Array(Set(entryNamesToFetch).union(localEntryNames)).sorted()
        try await savePublicBoardRecord(
            boardRecord,
            groupHash: groupHash,
            inviteCode: normalizedCode,
            entryNames: savedEntryNames
        )

        let savedEntries = mergedEntries(remoteEntries + localEntries)
        return savedEntries
    }

    func prepareHouseholdShare(inviteCode: String, displayName: String) async throws -> HouseholdCompetitionShare {
        let normalizedCode = SharedCompetitionSettings.normalizedInviteCode(inviteCode)
        guard !normalizedCode.isEmpty else {
            throw CloudSyncError.unavailable("Create or paste a household code before sharing.")
        }

        try await requireAvailableAccount()
        let groupHash = Self.groupHash(for: normalizedCode)
        let zoneID = CKRecordZone.ID(zoneName: Self.shareZoneName, ownerName: CKCurrentUserDefaultName)
        try await ensureShareZone(zoneID: zoneID)

        let boardRecordID = CKRecord.ID(recordName: Self.boardRecordName(for: groupHash), zoneID: zoneID)
        let boardRecord = try await loadOrCreateBoardRecord(
            recordID: boardRecordID,
            groupHash: groupHash,
            inviteCode: normalizedCode,
            displayName: displayName
        )

        let share = CKShare(rootRecord: boardRecord)
        share[CKShare.SystemFieldKey.title] = "StepReceipt Household Board" as CKRecordValue
        share[CKShare.SystemFieldKey.shareType] = "com.tyronsamaroo.stepreceipt.household-board" as CKRecordValue
        share.publicPermission = .none

        do {
            _ = try await privateDatabase.modifyRecords(
                saving: [boardRecord, share],
                deleting: [],
                savePolicy: .changedKeys,
                atomically: true
            )
            return HouseholdCompetitionShare(share: share, container: container)
        } catch {
            throw CloudSyncError.unavailable("iCloud sharing could not be prepared: \(error.localizedDescription)")
        }
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

    private func ensureShareZone(zoneID: CKRecordZone.ID) async throws {
        do {
            _ = try await privateDatabase.recordZone(for: zoneID)
        } catch {
            guard isMissingRecord(error) else { throw error }
            do {
                _ = try await privateDatabase.modifyRecordZones(
                    saving: [CKRecordZone(zoneID: zoneID)],
                    deleting: []
                )
            } catch {
                guard !isAlreadyExists(error) else { return }
                throw CloudSyncError.unavailable("iCloud household sharing is still setting up. Try iCloud invite again in a moment.")
            }
        }
    }

    private func loadOrCreateBoardRecord(
        recordID: CKRecord.ID,
        groupHash: String,
        inviteCode: String,
        displayName: String
    ) async throws -> CKRecord {
        let record: CKRecord
        do {
            record = try await privateDatabase.record(for: recordID)
        } catch {
            guard isMissingRecord(error) else { throw error }
            record = CKRecord(recordType: Self.boardRecordType, recordID: recordID)
        }

        record["groupHash"] = groupHash
        record["schemaVersion"] = Self.schemaVersion
        record["inviteCodeHint"] = inviteCode
        record["ownerDisplayName"] = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        record["privacyBoundary"] = "competition-aggregates-only"
        record["updatedAt"] = Date()
        return record
    }

    private func loadOrCreatePublicBoardRecord(groupHash: String, inviteCode: String) async throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: Self.boardRecordName(for: groupHash))
        do {
            let record = try await database.record(for: recordID)
            updateBoardRecord(record, groupHash: groupHash, inviteCode: inviteCode, entryNames: entryRecordNames(from: record))
            return record
        } catch {
            guard isMissingRecord(error) else { throw error }
            let record = CKRecord(recordType: Self.boardRecordType, recordID: recordID)
            updateBoardRecord(record, groupHash: groupHash, inviteCode: inviteCode, entryNames: [])
            return record
        }
    }

    private func savePublicBoardRecord(
        _ boardRecord: CKRecord,
        groupHash: String,
        inviteCode: String,
        entryNames: [String]
    ) async throws {
        var record = boardRecord
        var namesToSave = entryNames

        for _ in 0..<3 {
            updateBoardRecord(record, groupHash: groupHash, inviteCode: inviteCode, entryNames: namesToSave)

            do {
                _ = try await database.save(record)
                return
            } catch {
                if let serverRecord = serverChangedRecord(from: error) {
                    namesToSave = Array(Set(namesToSave).union(entryRecordNames(from: serverRecord))).sorted()
                    record = serverRecord
                    continue
                }
                if isMissingRecord(error) {
                    record = CKRecord(
                        recordType: Self.boardRecordType,
                        recordID: CKRecord.ID(recordName: Self.boardRecordName(for: groupHash))
                    )
                    continue
                }
                throw error
            }
        }

        throw CloudSyncError.unavailable("Household board could not be saved.")
    }

    private func updateBoardRecord(
        _ record: CKRecord,
        groupHash: String,
        inviteCode: String,
        entryNames: [String]
    ) {
        let cappedEntryNames = Array(Set(entryNames)).sorted().prefix(Self.maxEntriesPerBoard)
        record["groupHash"] = groupHash
        record["schemaVersion"] = Self.schemaVersion
        record["inviteCodeHint"] = String(inviteCode.suffix(4))
        record["entryNames"] = Array(cappedEntryNames) as NSArray
        record["privacyBoundary"] = "competition-aggregates-only"
        record["updatedAt"] = Date()
    }

    private func entryRecordNames(from record: CKRecord) -> [String] {
        if let values = record["entryNames"] as? [String] {
            return values
        }
        if let values = record["entryNames"] as? NSArray {
            return values.compactMap { $0 as? String }
        }
        return []
    }

    private func fetchEntryRecords(recordNames: [String]) async throws -> [CKRecord] {
        let cappedNames = Array(Set(recordNames)).sorted().prefix(Self.maxEntriesPerBoard)
        guard !cappedNames.isEmpty else { return [] }

        var records: [CKRecord] = []
        let recordIDs = cappedNames.map { CKRecord.ID(recordName: $0) }
        var startIndex = 0

        while startIndex < recordIDs.count {
            let endIndex = min(startIndex + 100, recordIDs.count)
            let batch = Array(recordIDs[startIndex..<endIndex])
            let results = try await database.records(for: batch, desiredKeys: nil)
            records.append(contentsOf: successfulRecords(from: results))
            startIndex = endIndex
        }

        return records
    }

    private func successfulRecords(from matches: [CKRecord.ID: Result<CKRecord, Error>]) -> [CKRecord] {
        matches.values.compactMap { result in
            guard case .success(let record) = result else { return nil }
            return record
        }
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
        guard let error = error as? CKError else {
            return error.localizedDescription.localizedCaseInsensitiveContains("does not exist")
        }
        return error.code == .unknownItem || error.code == .zoneNotFound
    }

    private func isAlreadyExists(_ error: Error) -> Bool {
        guard let error = error as? CKError else {
            return error.localizedDescription.localizedCaseInsensitiveContains("already exist")
        }
        return error.code == .serverRejectedRequest &&
            error.localizedDescription.localizedCaseInsensitiveContains("already exist")
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
