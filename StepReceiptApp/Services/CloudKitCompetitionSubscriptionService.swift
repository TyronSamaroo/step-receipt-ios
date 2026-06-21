import CloudKit
import Foundation

struct CompetitionSubscriptionPlan: Equatable, Sendable {
    let subscriptionID: String
    let groupHash: String
    let recordType: String
    let predicateFormat: String

    static func plan(for groupHash: String) -> CompetitionSubscriptionPlan {
        CompetitionSubscriptionPlan(
            subscriptionID: CloudKitCompetitionSubscriptionService.subscriptionID(for: groupHash),
            groupHash: groupHash,
            recordType: CloudKitCompetitionSubscriptionService.entryRecordType,
            predicateFormat: "groupHash == %@"
        )
    }
}

protocol CompetitionSubscriptionManaging: Sendable {
    func register(for groupHash: String) async throws
    func unregisterCurrent() async throws
    func registeredGroupHash() -> String?
}

enum CloudKitCompetitionSubscriptionService {
    static let entryRecordType = "CompetitionEntry"
    static let registeredGroupHashKey = "stepReceipt.competitionSubscriptionGroupHash.v1"

    static func subscriptionID(for groupHash: String) -> String {
        "compete-entry-\(String(groupHash.prefix(32)))"
    }

    static func makeQuerySubscription(plan: CompetitionSubscriptionPlan) -> CKQuerySubscription {
        let predicate = NSPredicate(format: plan.predicateFormat, plan.groupHash)
        let subscription = CKQuerySubscription(
            recordType: plan.recordType,
            predicate: predicate,
            subscriptionID: plan.subscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        return subscription
    }
}

final class LiveCloudKitCompetitionSubscriptionService: @unchecked Sendable, CompetitionSubscriptionManaging {
    private let database: CKDatabase
    private let userDefaults: UserDefaults

    init(
        containerIdentifier: String = "iCloud.com.tyronsamaroo.stepreceipt",
        userDefaults: UserDefaults = .standard
    ) {
        let container = CKContainer(identifier: containerIdentifier)
        database = container.publicCloudDatabase
        self.userDefaults = userDefaults
    }

    func register(for groupHash: String) async throws {
        let plan = CompetitionSubscriptionPlan.plan(for: groupHash)
        let subscription = CloudKitCompetitionSubscriptionService.makeQuerySubscription(plan: plan)

        if let previousHash = registeredGroupHash(), previousHash != groupHash {
            try await unregisterSubscription(for: previousHash)
        }

        _ = try await database.save(subscription)
        userDefaults.set(groupHash, forKey: CloudKitCompetitionSubscriptionService.registeredGroupHashKey)
    }

    func unregisterCurrent() async throws {
        guard let groupHash = registeredGroupHash() else { return }
        try await unregisterSubscription(for: groupHash)
        userDefaults.removeObject(forKey: CloudKitCompetitionSubscriptionService.registeredGroupHashKey)
    }

    func registeredGroupHash() -> String? {
        userDefaults.string(forKey: CloudKitCompetitionSubscriptionService.registeredGroupHashKey)
    }

    private func unregisterSubscription(for groupHash: String) async throws {
        let subscriptionID = CloudKitCompetitionSubscriptionService.subscriptionID(for: groupHash)
        _ = try await database.deleteSubscription(withID: subscriptionID)
    }
}

struct DisabledCompetitionSubscriptionService: CompetitionSubscriptionManaging, Sendable {
    func register(for groupHash: String) async throws {}
    func unregisterCurrent() async throws {}
    func registeredGroupHash() -> String? { nil }
}

#if canImport(UIKit)
import UIKit

enum CompetitionPushRegistration {
    @MainActor
    static func registerIfNeeded(boardEnabled: Bool) {
        guard boardEnabled else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }
}
#endif
