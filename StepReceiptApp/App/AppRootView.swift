import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var repository: ActivityRepository

    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: StepReceiptSymbol.todayTab)
                }

            ActivityHistoryView()
                .tabItem {
                    Label("Activity", systemImage: StepReceiptSymbol.activityTab)
                }

            CompetitionView()
                .tabItem {
                    Label("Compete", systemImage: StepReceiptSymbol.competitionTab)
                }

            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: StepReceiptSymbol.insightsTab)
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: StepReceiptSymbol.settingsTab)
                }
        }
        .tint(.stepAccent)
        .preferredColorScheme(repository.preferences.appTheme.colorScheme)
        .overlay {
            if repository.authorizationState == .notDetermined {
                PermissionOnboardingView()
                    .transition(.opacity)
            }
        }
    }
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
