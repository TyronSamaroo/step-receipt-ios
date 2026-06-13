import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var repository: ActivityRepository
    @State private var selectedTab: StepReceiptTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            ActivityHistoryView()
                .tabItem {
                    Label("Activity", systemImage: StepReceiptSymbol.activityTab)
                }
                .tag(StepReceiptTab.activity)

            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: StepReceiptSymbol.insightsTab)
                }
                .tag(StepReceiptTab.insights)

            TodayView()
                .tabItem {
                    Label("Today", systemImage: StepReceiptSymbol.todayTab)
                }
                .tag(StepReceiptTab.today)

            CompetitionView()
                .tabItem {
                    Label("Compete", systemImage: StepReceiptSymbol.competitionTab)
                }
                .tag(StepReceiptTab.compete)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: StepReceiptSymbol.settingsTab)
                }
                .tag(StepReceiptTab.settings)
        }
        .tint(.stepAccent)
        .preferredColorScheme(repository.preferences.appTheme.colorScheme)
    }
}

private enum StepReceiptTab: Hashable {
    case activity
    case insights
    case today
    case compete
    case settings
}

private extension AppTheme {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
