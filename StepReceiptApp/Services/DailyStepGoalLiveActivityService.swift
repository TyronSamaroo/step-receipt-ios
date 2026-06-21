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

protocol DailyStepGoalLiveActivityServicing: Sendable {
    var status: DailyStepGoalLiveActivityStatus { get }

    func start(summary: DailyActivitySummary) async -> DailyStepGoalLiveActivityStatus
    func updateIfActive(summary: DailyActivitySummary) async -> DailyStepGoalLiveActivityStatus
    func update(summary: DailyActivitySummary) async -> DailyStepGoalLiveActivityStatus
    func end(summary: DailyActivitySummary?) async -> DailyStepGoalLiveActivityStatus
}

final class DailyStepGoalLiveActivityService: DailyStepGoalLiveActivityServicing, @unchecked Sendable {
    private var currentActivities: [Activity<DailyStepGoalAttributes>] {
        Activity<DailyStepGoalAttributes>.activities
    }

    var status: DailyStepGoalLiveActivityStatus {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return .unavailable("Live Activities are disabled for StrideSlip in iOS Settings.")
        }

        guard let activity = currentActivities.first else {
            return .inactive
        }

        return .active(updatedAt: activity.content.state.updatedAt)
    }

    func start(summary: DailyActivitySummary) async -> DailyStepGoalLiveActivityStatus {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return .unavailable("Live Activities are disabled for StrideSlip in iOS Settings.")
        }

        await endStaleActivities(notMatching: summary.dateStart)

        let updatedAt = Date()
        let content = ActivityContent(
            state: contentState(for: summary, updatedAt: updatedAt),
            staleDate: staleDate(from: updatedAt)
        )

        do {
            if let existingActivity = activity(for: summary.dateStart) {
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
            return .unavailable("Live Activities are disabled for StrideSlip in iOS Settings.")
        }

        await endStaleActivities(notMatching: summary.dateStart)

        guard let existingActivity = activity(for: summary.dateStart) else {
            return status
        }

        let updatedAt = Date()
        let content = ActivityContent(
            state: contentState(for: summary, updatedAt: updatedAt),
            staleDate: staleDate(from: updatedAt)
        )

        await existingActivity.update(content)

        return status
    }

    func end(summary: DailyActivitySummary?) async -> DailyStepGoalLiveActivityStatus {
        let content = summary.map {
            ActivityContent(
                state: contentState(for: $0, updatedAt: Date()),
                staleDate: nil
            )
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

    private func activity(for dayStart: Date) -> Activity<DailyStepGoalAttributes>? {
        currentActivities.first {
            Calendar.current.isDate($0.attributes.dayStart, inSameDayAs: dayStart)
        }
    }

    private func endStaleActivities(notMatching dayStart: Date) async {
        for activity in currentActivities where !Calendar.current.isDate(activity.attributes.dayStart, inSameDayAs: dayStart) {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func contentState(
        for summary: DailyActivitySummary,
        updatedAt: Date
    ) -> DailyStepGoalAttributes.ContentState {
        DailyStepGoalAttributes.ContentState(
            steps: summary.steps,
            stepGoal: summary.goals.stepsPerDay,
            updatedAt: updatedAt
        )
    }

    private func staleDate(from updatedAt: Date) -> Date {
        updatedAt.addingTimeInterval(60 * 60 * 2)
    }
}
