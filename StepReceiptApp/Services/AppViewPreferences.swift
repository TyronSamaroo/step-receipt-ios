import Foundation

enum AppViewPreferenceKey {
    static let activityMode = "stepReceipt.activityHistory.mode.v1"
    static let activityDayFilter = "stepReceipt.activityHistory.dayFilter.v1"
    static let activityDaySort = "stepReceipt.activityHistory.daySort.v1"
    static let activityWorkoutFilter = "stepReceipt.activityHistory.workoutFilter.v1"
    static let insightsScope = "stepReceipt.insights.scope.v1"
    static let insightsTrendFilter = "stepReceipt.insights.trendFilter.v1"
    static let cardioSessionScope = "stepReceipt.insights.cardioSessionScope.v1"
    static let activityWorkoutShowStats = "stepReceipt.activityHistory.workoutShowStats.v1"

    static let all = [
        activityMode,
        activityDayFilter,
        activityDaySort,
        activityWorkoutFilter,
        activityWorkoutShowStats,
        insightsScope,
        insightsTrendFilter,
        cardioSessionScope
    ]
}

enum AppViewPreferenceDefault {
    static let activityMode = "days"
    static let activityDayFilter = DailySummaryFilter.all.rawValue
    static let activityDaySort = DailySummarySort.newest.rawValue
    static let activityWorkoutFilter = "all"
    static let insightsScope = ActivityPeriodScope.week.rawValue
    static let insightsTrendFilter = InsightsTrendFilter.all.rawValue
    static let cardioSessionScope = CardioSessionScope.movement.rawValue
    static let activityWorkoutShowStats = false
}

struct AppViewPreferenceStore {
    let userDefaults: UserDefaults

    func string(for key: String, defaultValue: String) -> String {
        userDefaults.string(forKey: key) ?? defaultValue
    }

    func set(_ value: String, for key: String) {
        userDefaults.set(value, forKey: key)
    }
}
