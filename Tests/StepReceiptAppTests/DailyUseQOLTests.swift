import Foundation
import Testing

struct DailyUseQOLTests {
    @Test
    func testViewPreferenceDefaultsAndPersistence() throws {
        let suiteName = "StepReceiptViewPreferences.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AppViewPreferenceStore(userDefaults: defaults)

        #expect(store.string(for: AppViewPreferenceKey.activityMode, defaultValue: AppViewPreferenceDefault.activityMode) == "days")
        #expect(store.string(for: AppViewPreferenceKey.activityDayFilter, defaultValue: AppViewPreferenceDefault.activityDayFilter) == "all")
        #expect(store.string(for: AppViewPreferenceKey.activityDaySort, defaultValue: AppViewPreferenceDefault.activityDaySort) == "newest")
        #expect(store.string(for: AppViewPreferenceKey.activityWorkoutFilter, defaultValue: AppViewPreferenceDefault.activityWorkoutFilter) == "all")
        #expect(store.string(for: AppViewPreferenceKey.insightsScope, defaultValue: AppViewPreferenceDefault.insightsScope) == "week")
        #expect(store.string(for: AppViewPreferenceKey.insightsTrendFilter, defaultValue: AppViewPreferenceDefault.insightsTrendFilter) == "all")

        store.set("workouts", for: AppViewPreferenceKey.activityMode)
        store.set("goalHit", for: AppViewPreferenceKey.activityDayFilter)
        store.set("steps", for: AppViewPreferenceKey.activityDaySort)
        store.set("outdoorWalk", for: AppViewPreferenceKey.activityWorkoutFilter)
        store.set("month", for: AppViewPreferenceKey.insightsScope)
        store.set("strength", for: AppViewPreferenceKey.insightsTrendFilter)

        let restoredStore = AppViewPreferenceStore(userDefaults: defaults)
        #expect(restoredStore.string(for: AppViewPreferenceKey.activityMode, defaultValue: AppViewPreferenceDefault.activityMode) == "workouts")
        #expect(restoredStore.string(for: AppViewPreferenceKey.activityDayFilter, defaultValue: AppViewPreferenceDefault.activityDayFilter) == "goalHit")
        #expect(restoredStore.string(for: AppViewPreferenceKey.activityDaySort, defaultValue: AppViewPreferenceDefault.activityDaySort) == "steps")
        #expect(restoredStore.string(for: AppViewPreferenceKey.activityWorkoutFilter, defaultValue: AppViewPreferenceDefault.activityWorkoutFilter) == "outdoorWalk")
        #expect(restoredStore.string(for: AppViewPreferenceKey.insightsScope, defaultValue: AppViewPreferenceDefault.insightsScope) == "month")
        #expect(restoredStore.string(for: AppViewPreferenceKey.insightsTrendFilter, defaultValue: AppViewPreferenceDefault.insightsTrendFilter) == "strength")
        #expect(restoredStore.string(for: AppViewPreferenceKey.activityWorkoutShowStats, defaultValue: "false") == "false")

        store.set("true", for: AppViewPreferenceKey.activityWorkoutShowStats)
        let statsStore = AppViewPreferenceStore(userDefaults: defaults)
        #expect(statsStore.string(for: AppViewPreferenceKey.activityWorkoutShowStats, defaultValue: "false") == "true")
    }

    @Test
    func testDiagnosticsSummaryExcludesRawActivityData() {
        let summary = AppDiagnosticsSummary(
            appVersion: "0.1.0",
            appBuild: "19",
            appleHealthStatus: "Connected",
            healthRefreshStatus: "Current",
            healthLastRefresh: "8:41 PM",
            healthBackgroundUpdates: "Ready",
            iCloudStatus: "Available",
            liveActivityStatus: "Live Activity on",
            competeBoardStatus: "Active",
            competeMemberCount: 2,
            competeSyncStatus: "Synced"
        )

        let text = summary.text

        #expect(text.contains("StrideSlip Diagnostics"))
        #expect(text.contains("App: 0.1.0 (19)"))
        #expect(text.contains("Apple Health: Connected"))
        #expect(text.contains("Background Updates: Ready"))
        #expect(text.contains("Last Health Refresh: 8:41 PM"))
        #expect(text.contains("iCloud: Available"))
        #expect(text.contains("Household Board: Active"))
        #expect(text.contains("Household Members: 2"))
        #expect(text.contains("Compete Sync: Synced"))
        #expect(text.contains("Live Activity: Live Activity on"))

        let lowercased = text.lowercased()
        #expect(!lowercased.contains("sourceidentifier"))
        #expect(!lowercased.contains("source name"))
        #expect(!lowercased.contains("route"))
        #expect(!lowercased.contains("heart-rate samples"))
        #expect(!lowercased.contains("workouts"))
        #expect(!lowercased.contains("steps:"))
        #expect(!lowercased.contains("distance"))
        #expect(!lowercased.contains("calories"))
        #expect(!lowercased.contains("household code"))
        #expect(!lowercased.contains("familybeta"))
    }
}
