import ActivityKit
import Foundation

struct DailyStepGoalAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let steps: Int
        let stepGoal: Int
        let updatedAt: Date

        init(steps: Int, stepGoal: Int, updatedAt: Date = Date()) {
            self.steps = max(0, steps)
            self.stepGoal = max(1, stepGoal)
            self.updatedAt = updatedAt
        }

        var progress: Double {
            min(1, Double(steps) / Double(stepGoal))
        }

        var remainingSteps: Int {
            max(0, stepGoal - steps)
        }

        var isGoalComplete: Bool {
            steps >= stepGoal
        }
    }

    let dayStart: Date

    init(dayStart: Date) {
        self.dayStart = dayStart
    }
}
