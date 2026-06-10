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
        .overlay {
            if repository.authorizationState == .notDetermined {
                PermissionOnboardingView()
                    .transition(.opacity)
            }
        }
    }
}
