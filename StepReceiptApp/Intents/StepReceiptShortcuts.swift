import AppIntents

struct StepReceiptShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetTodayStepsIntent(),
            phrases: [
                "Get my steps in \(.applicationName)",
                "How many steps today in \(.applicationName)"
            ],
            shortTitle: "Today's Steps",
            systemImageName: "figure.walk"
        )
        AppShortcut(
            intent: SyncHouseholdBoardIntent(),
            phrases: [
                "Sync household board in \(.applicationName)",
                "Refresh compete board in \(.applicationName)"
            ],
            shortTitle: "Sync Compete Board",
            systemImageName: "arrow.triangle.2.circlepath"
        )
        AppShortcut(
            intent: OpenCompeteIntent(),
            phrases: [
                "Open compete in \(.applicationName)",
                "Show household leaderboard in \(.applicationName)"
            ],
            shortTitle: "Open Compete",
            systemImageName: "trophy"
        )
    }
}
