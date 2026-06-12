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

        var progressPercent: Int {
            Int((progress * 100).rounded())
        }

        var progressPercentText: String {
            "\(progressPercent)%"
        }

        var compactStepsText: String {
            if steps >= 10_000 {
                return "\(steps / 1_000)k"
            }

            if steps >= 1_000 {
                return String(format: "%.1fk", Double(steps) / 1_000)
            }

            return steps.formatted()
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
