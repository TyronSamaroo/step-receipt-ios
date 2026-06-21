import CloudKit
import Foundation
import Testing

struct CompetitionSubscriptionTests {
    @Test
    func testSubscriptionIDIsStableForGroupHash() {
        let hash = CloudKitCompetitionSync.groupHash(for: "FAMILYBETA")
        let first = CloudKitCompetitionSubscriptionService.subscriptionID(for: hash)
        let second = CloudKitCompetitionSubscriptionService.subscriptionID(for: hash)
        #expect(first == second)
        #expect(first.hasPrefix("compete-entry-"))
    }

    @Test
    func testSubscriptionPlanTargetsCompetitionEntryGroupHash() {
        let hash = CloudKitCompetitionSync.groupHash(for: "SRWIFE2026")
        let plan = CompetitionSubscriptionPlan.plan(for: hash)
        #expect(plan.recordType == "CompetitionEntry")
        #expect(plan.predicateFormat == "groupHash == %@")
        #expect(plan.groupHash == hash)
        #expect(plan.subscriptionID == CloudKitCompetitionSubscriptionService.subscriptionID(for: hash))
    }

    @Test
    func testQuerySubscriptionUsesSilentPushNotificationInfo() {
        let hash = CloudKitCompetitionSync.groupHash(for: "HOUSEHOLD1")
        let plan = CompetitionSubscriptionPlan.plan(for: hash)
        let subscription = CloudKitCompetitionSubscriptionService.makeQuerySubscription(plan: plan)

        #expect(subscription.recordType == "CompetitionEntry")
        #expect(subscription.subscriptionID == plan.subscriptionID)
        #expect(subscription.notificationInfo?.shouldSendContentAvailable == true)
        #expect(subscription.querySubscriptionOptions.contains(.firesOnRecordUpdate))
    }

    @Test
    func testDisabledSubscriptionServiceIsNoOp() async {
        let service = DisabledCompetitionSubscriptionService()
        await #expect(service.registeredGroupHash() == nil)
        try await service.register(for: "abc")
        try await service.unregisterCurrent()
        await #expect(service.registeredGroupHash() == nil)
    }
}
