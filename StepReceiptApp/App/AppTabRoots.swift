import SwiftUI

struct ActivityTabRoot: View {
    var body: some View {
        ActivityHistoryView()
    }
}

struct InsightsTabRoot: View {
    var body: some View {
        InsightsView()
    }
}

struct TodayTabRoot: View {
    var body: some View {
        TodayView()
    }
}

struct CompeteTabRoot: View {
    var body: some View {
        CompetitionView()
    }
}

struct SettingsTabRoot: View {
    var body: some View {
        SettingsView()
    }
}
