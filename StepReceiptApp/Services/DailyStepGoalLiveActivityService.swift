@preconcurrency import ActivityKit
import Foundation

enum DailyStepGoalLiveActivityStatus: Equatable {
    case inactive
    case active(updatedAt: Date)
    case unavailable(String)

    var isActive: Bool {
        if case .active = self { return true }
        return false
    }

    var title: String {
        switch self {
        case .inactive:
            "Live Activity off"
        case .active:
            "Live Activity on"
        case .unavailable:
            "Live Activity unavailable"
        }
    }

    var detail: String {
        switch self {
        case .inactive:
            "Start it when you want the Lock Screen to show today's step goal."
        case .active(let updatedAt):
            "Last updated \(updatedAt.formatted(date: .omitted, time: .shortened))."
        case .unavailable(let reason):
            reason
        }
    }
}

final class DailyStepGoalLiveActivityService: @unchecked Sendable {
    private var currentActivities: [Activity<DailyStepGoalAttributes>] {
        Activity<DailyStepGoalAttributes>.activities
    }

    var status: DailyStepGoalLiveActivityStatus {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return .unavailable("Live Activities are disabled for StepReceipt in iOS Settings.")
        }

        guard let activity = currentActivities.first else {
            return .inactive
        }

        return .active(updatedAt: activity.content.state.updatedAt)
    }

    func start(summary: DailyActivitySummary) async -> DailyStepGoalLiveActivityStatus {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return .unavailable("Live Activities are disabled for StepReceipt in iOS Settings.")
        }

        let content = ActivityContent(
            state: contentState(for: summary),
            staleDate: staleDate()
        )

        do {
            if let existingActivity = currentActivities.first {
                await existingActivity.update(content)
            } else {
                _ = try Activity.request(
                    attributes: DailyStepGoalAttributes(dayStart: summary.dateStart),
                    content: content,
                    pushType: nil
                )
            }
        } catch {
            return .unavailable(error.localizedDescription)
        }

        return status
    }

    func updateIfActive(summary: DailyActivitySummary) async -> DailyStepGoalLiveActivityStatus {
        guard !currentActivities.isEmpty else {
            return status
        }

        return await update(summary: summary)
    }

    func update(summary: DailyActivitySummary) async -> DailyStepGoalLiveActivityStatus {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return .unavailable("Live Activities are disabled for StepReceipt in iOS Settings.")
        }

        let content = ActivityContent(
            state: contentState(for: summary),
            staleDate: staleDate()
        )

        for activity in currentActivities {
            await activity.update(content)
        }

        return status
    }

    func end(summary: DailyActivitySummary?) async -> DailyStepGoalLiveActivityStatus {
        let content = summary.map {
            ActivityContent(state: contentState(for: $0), staleDate: nil)
        }

        for activity in currentActivities {
            if let content {
                await activity.end(content, dismissalPolicy: .default)
            } else {
                await activity.end(nil, dismissalPolicy: .default)
            }
        }

        return status
    }

    private func contentState(for summary: DailyActivitySummary) -> DailyStepGoalAttributes.ContentState {
        DailyStepGoalAttributes.ContentState(
            steps: summary.steps,
            stepGoal: summary.goals.stepsPerDay
        )
    }

    private func staleDate() -> Date {
        Date().addingTimeInterval(60 * 60 * 2)
    }
}
