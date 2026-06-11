import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {
    static let stepBackground = Color(red: 0.965, green: 0.972, blue: 0.956)
    static let stepInk = Color(red: 0.075, green: 0.090, blue: 0.086)
    static let stepMuted = Color(red: 0.255, green: 0.300, blue: 0.282)
    static let stepAxis = Color(red: 0.170, green: 0.210, blue: 0.195)
    static let stepAxisGrid = Color(red: 0.075, green: 0.090, blue: 0.086).opacity(0.18)
    static let stepAccent = Color(red: 0.075, green: 0.445, blue: 0.375)
    static let stepEnergy = Color(red: 0.910, green: 0.390, blue: 0.210)
    static let stepDistance = Color(red: 0.200, green: 0.390, blue: 0.760)
    static let stepWarning = Color(red: 0.760, green: 0.290, blue: 0.180)
    static let stepSurface = Color.white
}

#if canImport(UIKit)
enum StepReceiptChrome {
    @MainActor
    static func configure() {
        let background = UIColor(red: 0.965, green: 0.972, blue: 0.956, alpha: 1)
        let surface = UIColor.white
        let ink = UIColor(red: 0.075, green: 0.090, blue: 0.086, alpha: 1)
        let muted = UIColor(red: 0.255, green: 0.300, blue: 0.282, alpha: 1)
        let accent = UIColor(red: 0.075, green: 0.445, blue: 0.375, alpha: 1)

        let navigation = UINavigationBarAppearance()
        navigation.configureWithOpaqueBackground()
        navigation.backgroundColor = background
        navigation.titleTextAttributes = [.foregroundColor: ink]
        navigation.largeTitleTextAttributes = [.foregroundColor: ink]
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().compactAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = navigation

        let tabBar = UITabBarAppearance()
        tabBar.configureWithOpaqueBackground()
        tabBar.backgroundColor = surface
        tabBar.shadowColor = UIColor.black.withAlphaComponent(0.12)

        let normalAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: muted]
        let selectedAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: accent]
        for itemAppearance in [
            tabBar.stackedLayoutAppearance,
            tabBar.inlineLayoutAppearance,
            tabBar.compactInlineLayoutAppearance
        ] {
            itemAppearance.normal.iconColor = muted
            itemAppearance.normal.titleTextAttributes = normalAttributes
            itemAppearance.selected.iconColor = accent
            itemAppearance.selected.titleTextAttributes = selectedAttributes
        }

        UITabBar.appearance().standardAppearance = tabBar
        UITabBar.appearance().scrollEdgeAppearance = tabBar
        UITabBar.appearance().tintColor = accent
        UITabBar.appearance().unselectedItemTintColor = muted
    }
}
#endif

struct MetricCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color.stepSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 8)
    }
}

extension View {
    func metricCard() -> some View {
        modifier(MetricCardStyle())
    }
}

enum StepReceiptSymbol {
    static let activityTab = "list.bullet"
    static let activeEnergy = "flame"
    static let cloud = "icloud"
    static let competitionTab = "person.3"
    static let distance = "map"
    static let health = "heart.fill"
    static let insightsTab = "receipt"
    static let receipt = "receipt.fill"
    static let refresh = "arrow.clockwise"
    static let settingsTab = "gearshape"
    static let share = "square.and.arrow.up"
    static let steps = "figure.walk"
    static let todayTab = "figure.walk"
    static let workout = "timer"
    static let healthCard = "heart.fill"
    static let healthCardFill = "heart.fill"
    static let stairClimbing = "arrow.up"
    static let stepPrints = "figure.walk"

    static func workoutIcon(for kind: ActivityKind) -> String {
        switch kind {
        case .walking:
            steps
        case .running:
            "figure.run"
        case .cycling:
            "bicycle"
        case .strengthTraining:
            activeEnergy
        case .hiking:
            distance
        case .swimming:
            "drop"
        case .elliptical:
            "arrow.triangle.2.circlepath"
        case .stairClimbing:
            stairClimbing
        case .rowing:
            "drop"
        case .yoga:
            "leaf"
        case .other:
            "circle.grid.2x2"
        }
    }
}
