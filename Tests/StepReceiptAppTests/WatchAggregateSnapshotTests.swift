import Foundation
import Testing

struct WatchAggregateSnapshotTests {
    @Test
    func testSnapshotEncodesAndDecodesThroughWatchContext() {
        let snapshot = WatchAggregateSnapshot(
            steps: 4_820,
            stepGoal: 10_000,
            competeRank: 2,
            competeHeadline: "You are ranked #2 for steps.",
            householdBoardActive: true
        )

        guard let encoded = snapshot.encodedContextValue() else {
            Issue.record("Expected encoded snapshot")
            return
        }

        let decoded = WatchAggregateSnapshot.decode(from: encoded)
        #expect(decoded == snapshot)
        #expect(WatchAggregateSnapshot.decode(from: [WatchAggregateSnapshot.contextKey: encoded]) == snapshot)
    }

    @Test
    func testProgressPercentClampsAtGoal() {
        let snapshot = WatchAggregateSnapshot(steps: 12_500, stepGoal: 10_000)
        #expect(snapshot.progressPercent == 100)
    }
}
