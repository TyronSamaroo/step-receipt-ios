import Foundation
import Testing

struct DailyStepGoalAttributesTests {
    @Test
    func testStepGoalContentStateFormatsCompactStepsAndPercent() {
        let state = DailyStepGoalAttributes.ContentState(
            steps: 12_543,
            stepGoal: 20_000,
            updatedAt: Date(timeIntervalSince1970: 0)
        )

        #expect(state.progressPercent == 63)
        #expect(state.progressPercentText == "63%")
        #expect(state.compactStepsText == "12k")
        #expect(state.remainingSteps == 7_457)
        #expect(!state.isGoalComplete)
    }

    @Test
    func testStepGoalContentStateCapsProgressAtComplete() {
        let state = DailyStepGoalAttributes.ContentState(
            steps: 10_500,
            stepGoal: 10_000,
            updatedAt: Date(timeIntervalSince1970: 0)
        )

        #expect(state.progress == 1)
        #expect(state.progressPercentText == "100%")
        #expect(state.remainingSteps == 0)
        #expect(state.isGoalComplete)
    }
}
