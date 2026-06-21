import CloudKit
import Foundation

struct CompetitionSyncDiagnostics: Equatable {
    let boardEnabled: Bool
    let inviteCodeHint: String?
    let memberCount: Int
    let remoteEntryCount: Int
    let lastSyncState: String
    let lastSyncDetail: String
    let lastSyncedAt: Date?
    let boardRecordHashSuffix: String?
    let cloudKitCompetitionAvailable: Bool
    let iCloudAccountStatus: String?
    let pushRegistrationState: String?
    let subscriptionRegistered: Bool?
    let schemaLikelyMissing: Bool
    let localEntriesQueued: Int?

    init(
        boardEnabled: Bool,
        inviteCodeHint: String?,
        memberCount: Int,
        remoteEntryCount: Int,
        lastSyncState: String,
        lastSyncDetail: String,
        lastSyncedAt: Date?,
        boardRecordHashSuffix: String?,
        cloudKitCompetitionAvailable: Bool,
        iCloudAccountStatus: String? = nil,
        pushRegistrationState: String? = nil,
        subscriptionRegistered: Bool? = nil,
        schemaLikelyMissing: Bool = false,
        localEntriesQueued: Int? = nil
    ) {
        self.boardEnabled = boardEnabled
        self.inviteCodeHint = inviteCodeHint
        self.memberCount = memberCount
        self.remoteEntryCount = remoteEntryCount
        self.lastSyncState = lastSyncState
        self.lastSyncDetail = lastSyncDetail
        self.lastSyncedAt = lastSyncedAt
        self.boardRecordHashSuffix = boardRecordHashSuffix
        self.cloudKitCompetitionAvailable = cloudKitCompetitionAvailable
        self.iCloudAccountStatus = iCloudAccountStatus
        self.pushRegistrationState = pushRegistrationState
        self.subscriptionRegistered = subscriptionRegistered
        self.schemaLikelyMissing = schemaLikelyMissing
        self.localEntriesQueued = localEntriesQueued
    }

    var textLines: [String] {
        var lines = [
            "Household Board: \(boardEnabled ? "enabled" : "off")",
            "Members: \(memberCount)",
            "Remote Entries: \(remoteEntryCount)",
            "Compete Sync: \(lastSyncState)",
            "Compete Detail: \(lastSyncDetail)",
            "CloudKit Compete: \(cloudKitCompetitionAvailable ? "available" : "disabled build")"
        ]
        if let inviteCodeHint, !inviteCodeHint.isEmpty {
            lines.insert("Code Hint: ...\(inviteCodeHint)", at: 1)
        }
        if let lastSyncedAt {
            lines.append("Last Synced: \(lastSyncedAt.formatted(date: .abbreviated, time: .shortened))")
        }
        if let boardRecordHashSuffix {
            lines.append("Board Hash: ...\(boardRecordHashSuffix)")
        }
        if let iCloudAccountStatus {
            lines.append("iCloud: \(iCloudAccountStatus)")
        }
        if let pushRegistrationState {
            lines.append("Push: \(pushRegistrationState)")
        }
        if let subscriptionRegistered {
            lines.append("Subscription: \(subscriptionRegistered ? "registered" : "missing")")
        }
        if schemaLikelyMissing {
            lines.append("Schema: likely missing (see Docs/CloudKitCompetitionSchema.md)")
        }
        if let localEntriesQueued {
            lines.append("Local Rows Queued: \(localEntriesQueued)")
        }
        return lines
    }

    static func schemaLikelyMissing(from syncDetail: String) -> Bool {
        let lowered = syncDetail.lowercased()
        return lowered.contains("schema")
            || lowered.contains("unknown item")
            || lowered.contains("incomplete")
    }
}

enum CompetitionSyncPresentation {
    static func statusTitle(for state: CompetitionSyncState) -> String {
        switch state {
        case .off: "Off"
        case .idle: "Ready"
        case .syncing: "Syncing"
        case .synced: "Synced"
        case .unavailable(let reason):
            reason.localizedCaseInsensitiveContains("health") ? "Needs Health" : "Sync Issue"
        }
    }

    static func statusDetail(
        state: CompetitionSyncState,
        canSync: Bool,
        canPublishEntries: Bool
    ) -> String {
        if canSync, !canPublishEntries {
            return "Connect Health to publish your row."
        }

        switch state {
        case .off:
            return "Create or join a household board."
        case .idle:
            return "Ready to sync daily totals."
        case .syncing:
            return "Syncing daily totals only."
        case .synced(let date):
            return "Last synced \(date.formatted(date: .omitted, time: .shortened))."
        case .unavailable(let reason):
            return shortIssue(reason)
        }
    }

    static func shortIssue(_ reason: String) -> String {
        if reason.localizedCaseInsensitiveContains("health") {
            return "Connect Health, then sync."
        }
        if reason.localizedCaseInsensitiveContains("icloud") || reason.localizedCaseInsensitiveContains("sign in") {
            return "Check iCloud sign-in, then retry."
        }
        if reason.localizedCaseInsensitiveContains("schema") {
            return "CloudKit schema missing. See Docs/CloudKitCompetitionSchema.md."
        }
        if reason.localizedCaseInsensitiveContains("network") || reason.localizedCaseInsensitiveContains("offline") {
            return "Network issue. Retry."
        }
        return reason
            .split(separator: ".")
            .first
            .map(String.init) ?? "Needs attention."
    }

    static func iCloudAccountStatusLabel(_ status: CKAccountStatus) -> String {
        switch status {
        case .available: "signed in"
        case .noAccount: "not signed in"
        case .restricted: "restricted"
        case .couldNotDetermine: "unknown"
        case .temporarilyUnavailable: "temporarily unavailable"
        @unknown default: "unknown"
        }
    }
}
