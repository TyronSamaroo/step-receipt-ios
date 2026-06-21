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
    private static let syncDayWindow = 45
    private static let saveBatchSize = 25
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
        let localEntryNames = localEntries.map { Self.entryRecordName(groupHash: groupHash, entryID: $0.id) }
        let fallbackNames = Array(
            Set(entryRecordNames(from: boardRecord)).union(localEntryNames)
        ).sorted()
        let remoteRecords = try await fetchRecentEntryRecords(
            groupHash: groupHash,
            fallbackRecordNames: fallbackNames
        )
        var remoteByName = Dictionary(
            uniqueKeysWithValues: remoteRecords.map { ($0.recordID.recordName, $0) }
        )
        let remoteEntries = mergedEntries(remoteRecords.compactMap(entry(from:)))

        let entriesToSave = localEntries
            .filter { local in
                shouldUpload(local, groupHash: groupHash, remoteByName: remoteByName)
            }
            .sorted { $0.dayKey > $1.dayKey }
        try await saveLocalEntries(entriesToSave, groupHash: groupHash, remoteByName: &remoteByName)

        let savedEntryNames = Array(remoteByName.keys).sorted().suffix(Self.maxEntriesPerBoard)
        do {
            try await savePublicBoardRecord(
                boardRecord,
                groupHash: groupHash,
                inviteCode: normalizedCode,
                entryNames: Array(savedEntryNames)
            )
        } catch {
            // Daily rows may already be saved; don't fail the whole sync on board index conflicts.
            guard !entriesToSave.isEmpty else { throw error }
        }

        return mergedEntries(remoteEntries + localEntries)
    }

    private func shouldUpload(
        _ local: CompetitionEntry,
        groupHash: String,
        remoteByName: [String: CKRecord]
    ) -> Bool {
        let recordName = Self.entryRecordName(groupHash: groupHash, entryID: local.id)
        guard let existing = remoteByName[recordName], let remote = entry(from: existing) else {
            return true
        }
        if local.updatedAt > remote.updatedAt { return true }
        return local.steps != remote.steps
            || local.distanceMeters != remote.distanceMeters
            || local.activeEnergyKilocalories != remote.activeEnergyKilocalories
            || local.workoutMinutes != remote.workoutMinutes
            || local.competitor.displayName != remote.competitor.displayName
    }

    private func fetchRecentEntryRecords(groupHash: String, fallbackRecordNames: [String]) async throws -> [CKRecord] {
        do {
            return try await queryRecentEntryRecords(groupHash: groupHash)
        } catch {
            let capped = Array(Set(fallbackRecordNames)).sorted().suffix(Self.maxEntriesPerBoard)
            return try await fetchEntryRecords(recordNames: Array(capped))
        }
    }

    private func queryRecentEntryRecords(groupHash: String) async throws -> [CKRecord] {
        let cutoffDayKey = Self.recentCutoffDayKey()
        let predicate = NSPredicate(format: "groupHash == %@ AND dayKey >= %@", groupHash, cutoffDayKey)
        let query = CKQuery(recordType: Self.entryRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "dayKey", ascending: false)]

        var records: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?

        repeat {
            let page: ([(CKRecord.ID, Result<CKRecord, Error>)], CKQueryOperation.Cursor?)
            if let cursor {
                page = try await database.records(continuingMatchFrom: cursor, desiredKeys: nil)
            } else {
                page = try await database.records(
                    matching: query,
                    inZoneWith: nil,
                    desiredKeys: nil,
                    resultsLimit: Self.maxEntriesPerBoard
                )
            }
            records.append(contentsOf: successfulRecords(from: page.0))
            cursor = page.1
        } while cursor != nil && records.count < Self.maxEntriesPerBoard

        return records
    }

    private static func recentCutoffDayKey() -> String {
        let cutoff = Calendar.current.date(byAdding: .day, value: -syncDayWindow, to: Date()) ?? Date()
        return ActivityFormatting.dayKey(for: cutoff)
    }

    private func saveLocalEntries(
        _ entries: [CompetitionEntry],
        groupHash: String,
        remoteByName: inout [String: CKRecord]
    ) async throws {
        guard !entries.isEmpty else { return }

        var recordsToSave: [CKRecord] = []
        recordsToSave.reserveCapacity(entries.count)

        for entry in entries {
            let recordName = Self.entryRecordName(groupHash: groupHash, entryID: entry.id)
            let record = remoteByName[recordName] ?? CKRecord(
                recordType: Self.entryRecordType,
                recordID: CKRecord.ID(recordName: recordName)
            )
            update(record: record, groupHash: groupHash, entry: entry)
            recordsToSave.append(record)
        }

        var startIndex = 0
        while startIndex < recordsToSave.count {
            let endIndex = min(startIndex + Self.saveBatchSize, recordsToSave.count)
            let batch = Array(recordsToSave[startIndex..<endIndex])
            let saved = try await saveEntryBatch(batch)
            for record in saved {
                remoteByName[record.recordID.recordName] = record
            }
            startIndex = endIndex
        }
    }

    private func saveEntryBatch(_ records: [CKRecord]) async throws -> [CKRecord] {
        var pending = records
        var lastError: Error?

        for _ in 0..<3 {
            guard !pending.isEmpty else { return records }

            do {
                let result = try await database.modifyRecords(
                    saving: pending,
                    deleting: [],
                    savePolicy: .changedKeys
                )
                var saved: [CKRecord] = []
                var failed: [CKRecord] = []

                for record in pending {
                    let id = record.recordID
                    switch result.saveResults[id] {
                    case .success(let savedRecord):
                        saved.append(savedRecord)
                    case .failure(let error):
                        lastError = error
                        if let serverRecord = serverChangedRecord(from: error) {
                            failed.append(serverRecord)
                        } else if isMissingRecord(error) {
                            failed.append(CKRecord(recordType: Self.entryRecordType, recordID: id))
                        } else {
                            throw CloudSyncError.unavailable(
                                "Competition entry batch could not be saved. \(Self.friendlySyncMessage(for: error))"
                            )
                        }
                    case nil:
                        saved.append(record)
                    }
                }

                if failed.isEmpty {
                    return saved
                }
                pending = failed
            } catch let error as CKError where error.code == .partialFailure {
                lastError = error
                var failed: [CKRecord] = []
                for record in pending {
                    guard let itemError = error.partialErrorsByItemID?[record.recordID] else {
                        continue
                    }
                    if let serverRecord = serverChangedRecord(from: itemError) {
                        failed.append(serverRecord)
                    } else if isMissingRecord(itemError) {
                        failed.append(CKRecord(recordType: Self.entryRecordType, recordID: record.recordID))
                    } else {
                        throw CloudSyncError.unavailable(
                            "Competition entry batch could not be saved. \(Self.friendlySyncMessage(for: itemError))"
                        )
                    }
                }
                pending = failed
            } catch {
                throw CloudSyncError.unavailable(
                    "Competition entry batch could not be saved. \(Self.friendlySyncMessage(for: error))"
                )
            }
        }

        let detail = lastError.map { Self.friendlySyncMessage(for: $0) } ?? "Unknown iCloud error."
        throw CloudSyncError.unavailable("Competition entry batch could not be saved after retries. \(detail)")
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
        record["inviteCode"] = inviteCode
        record["inviteCodeHint"] = String(inviteCode.suffix(4))
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
        var remoteByName: [String: CKRecord] = [:]
        if let existingRecord {
            remoteByName[existingRecord.recordID.recordName] = existingRecord
        }
        try await saveLocalEntries([entry], groupHash: groupHash, remoteByName: &remoteByName)
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

    static func inviteCode(from boardRecord: CKRecord) -> String? {
        if let fullCode = boardRecord["inviteCode"] as? String {
            let normalized = SharedCompetitionSettings.normalizedInviteCode(fullCode)
            if !normalized.isEmpty { return normalized }
        }

        if let hint = boardRecord["inviteCodeHint"] as? String {
            let normalized = SharedCompetitionSettings.normalizedInviteCode(hint)
            if !normalized.isEmpty { return normalized }
        }

        return nil
    }

    static func ownerDisplayName(from boardRecord: CKRecord) -> String? {
        boardRecord["ownerDisplayName"] as? String
    }

    static func friendlySyncMessage(for error: Error) -> String {
        if let cloudError = error as? CloudSyncError {
            return cloudError.localizedDescription
        }

        guard let ckError = error as? CKError else {
            let description = error.localizedDescription
            if description.localizedCaseInsensitiveContains("schema") || description.localizedCaseInsensitiveContains("unknown item") {
                return "CloudKit schema is missing. Deploy HouseholdCompetitionBoard and CompetitionEntry in CloudKit Dashboard."
            }
            return description
        }

        switch ckError.code {
        case .notAuthenticated:
            return "Sign in to iCloud in Settings, then retry sync."
        case .networkUnavailable, .networkFailure:
            return "Network unavailable. Check connection and retry."
        case .serviceUnavailable, .requestRateLimited, .zoneBusy:
            return "iCloud is busy right now. Wait a moment and retry."
        case .permissionFailure, .incompatibleVersion:
            return "iCloud permission issue. Confirm CloudKit security roles for competition records."
        case .unknownItem, .invalidArguments:
            return "CloudKit schema is missing or incomplete. See Docs/CloudKitCompetitionSchema.md."
        case .serverRecordChanged:
            return "Board updated elsewhere. Pull to refresh and retry."
        case .partialFailure:
            if let partial = ckError.partialErrorsByItemID?.values.first {
                return friendlySyncMessage(for: partial)
            }
            return "Some competition rows could not sync. Retry."
        default:
            let description = ckError.localizedDescription
            if description.localizedCaseInsensitiveContains("icloud") {
                return "Check iCloud sign-in, then retry sync."
            }
            return description
        }
    }
}

extension CloudKitCompetitionSync: SharedCompetitionSyncing {}
