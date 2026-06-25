import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var repository: ActivityRepository
    @State private var selectedTab: StepReceiptTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            ActivityTabRoot()
                .tabItem {
                    Label("Activity", systemImage: StepReceiptSymbol.activityTab)
                }
                .tag(StepReceiptTab.activity)

            InsightsTabRoot()
                .tabItem {
                    Label("Insights", systemImage: StepReceiptSymbol.insightsTab)
                }
                .tag(StepReceiptTab.insights)

            TodayTabRoot()
                .tabItem {
                    Label("Today", systemImage: StepReceiptSymbol.todayTab)
                }
                .tag(StepReceiptTab.today)

            CompeteTabRoot()
                .tabItem {
                    Label("Compete", systemImage: StepReceiptSymbol.competitionTab)
                }
                .tag(StepReceiptTab.compete)

            SettingsTabRoot()
                .tabItem {
                    Label("Settings", systemImage: StepReceiptSymbol.settingsTab)
                }
                .tag(StepReceiptTab.settings)
        }
        .transaction { transaction in
            transaction.animation = nil
        }
        .tint(.stepAccent)
        .preferredColorScheme(repository.preferences.appTheme.colorScheme)
        .onChange(of: repository.activityNavigationToken) { _, _ in
            selectedTab = .activity
        }
        .onChange(of: repository.competeNavigationToken) { _, _ in
            selectedTab = .compete
        }
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
