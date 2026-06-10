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

    private let container: CKContainer
    private let database: CKDatabase
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

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

        var serverRecordForRetry: CKRecord?
        for _ in 0..<3 {
            let fetchedRecord: CKRecord?
            if let retryRecord = serverRecordForRetry {
                fetchedRecord = retryRecord
            } else {
                fetchedRecord = try await fetchBoardRecord(groupHash: groupHash)
            }
            guard let record = fetchedRecord ?? (localEntries.isEmpty ? nil : newBoardRecord(groupHash: groupHash)) else {
                return []
            }

            serverRecordForRetry = nil
            let remoteEntries = try decodedEntries(from: record)
            let merged = mergedEntries(remoteEntries + localEntries)
            guard !merged.isEmpty else { return [] }

            do {
                try update(record: record, groupHash: groupHash, entries: merged)
                let savedRecord = try await database.save(record)
                return try decodedEntries(from: savedRecord)
            } catch {
                if let serverRecord = serverChangedRecord(from: error) {
                    serverRecordForRetry = serverRecord
                    continue
                }
                throw error
            }
        }

        throw CloudSyncError.unavailable("Competition board could not be saved.")
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

    private func fetchBoardRecord(groupHash: String) async throws -> CKRecord? {
        do {
            return try await database.record(for: CKRecord.ID(recordName: Self.boardRecordName(for: groupHash)))
        } catch {
            if isMissingRecord(error) {
                return nil
            }
            throw error
        }
    }

    private func newBoardRecord(groupHash: String) -> CKRecord {
        CKRecord(recordType: "CompetitionBoard", recordID: CKRecord.ID(recordName: Self.boardRecordName(for: groupHash)))
    }

    private func update(record: CKRecord, groupHash: String, entries: [CompetitionEntry]) throws {
        let snapshot = CompetitionBoardSnapshot(
            schemaVersion: Self.schemaVersion,
            entries: entries.map(CompetitionEntrySnapshot.init),
            updatedAt: Date()
        )
        record["groupHash"] = groupHash
        record["schemaVersion"] = Self.schemaVersion
        record["entryCount"] = entries.count
        record["updatedAt"] = snapshot.updatedAt
        record["entriesJSON"] = try encoder.encode(snapshot) as NSData
    }

    private func decodedEntries(from record: CKRecord) throws -> [CompetitionEntry] {
        guard let value = record["entriesJSON"] else {
            return []
        }

        let data: Data?
        if let value = value as? Data {
            data = value
        } else if let value = value as? NSData {
            data = Data(referencing: value)
        } else {
            data = nil
        }

        guard let data else {
            throw CloudSyncError.unavailable("Competition board data could not be read.")
        }

        do {
            let snapshot = try decoder.decode(CompetitionBoardSnapshot.self, from: data)
            return mergedEntries(snapshot.entries.compactMap(\.entry))
        } catch {
            throw CloudSyncError.unavailable("Competition board data could not be decoded.")
        }
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
}

extension CloudKitCompetitionSync: SharedCompetitionSyncing {}

private struct CompetitionBoardSnapshot: Codable {
    let schemaVersion: Int
    let entries: [CompetitionEntrySnapshot]
    let updatedAt: Date
}

private struct CompetitionEntrySnapshot: Codable {
    let competitorID: UUID
    let displayName: String
    let initials: String?
    let accentHex: String
    let dayKey: String
    let steps: Int
    let distanceMeters: Double
    let activeEnergyKilocalories: Double
    let workoutMinutes: Double
    let updatedAt: Date

    init(entry: CompetitionEntry) {
        competitorID = entry.competitor.id
        displayName = entry.competitor.displayName
        initials = entry.competitor.initials
        accentHex = entry.competitor.accentHex
        dayKey = entry.dayKey
        steps = entry.steps
        distanceMeters = entry.distanceMeters
        activeEnergyKilocalories = entry.activeEnergyKilocalories
        workoutMinutes = entry.workoutMinutes
        updatedAt = entry.updatedAt
    }

    var entry: CompetitionEntry? {
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let competitor = CompetitorProfile(
            id: competitorID,
            displayName: displayName,
            initials: initials,
            accentHex: accentHex
        )
        return CompetitionEntry(
            competitor: competitor,
            dayKey: dayKey,
            steps: steps,
            distanceMeters: distanceMeters,
            activeEnergyKilocalories: activeEnergyKilocalories,
            workoutMinutes: workoutMinutes,
            updatedAt: updatedAt
        )
    }
}
