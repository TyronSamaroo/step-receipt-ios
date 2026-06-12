import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
private func stepUIColor(
    light: (Double, Double, Double),
    dark: (Double, Double, Double),
    alpha: Double = 1
) -> UIColor {
    UIColor { traits in
        let values = traits.userInterfaceStyle == .dark ? dark : light
        return UIColor(red: values.0, green: values.1, blue: values.2, alpha: alpha)
    }
}

private let stepBackgroundUIColor = stepUIColor(light: (0.965, 0.972, 0.956), dark: (0.055, 0.061, 0.058))
private let stepInkUIColor = stepUIColor(light: (0.075, 0.090, 0.086), dark: (0.940, 0.965, 0.950))
private let stepMutedUIColor = stepUIColor(light: (0.255, 0.300, 0.282), dark: (0.670, 0.720, 0.695))
private let stepAxisUIColor = stepUIColor(light: (0.170, 0.210, 0.195), dark: (0.760, 0.815, 0.790))
private let stepAxisGridUIColor = stepUIColor(light: (0.075, 0.090, 0.086), dark: (0.940, 0.965, 0.950), alpha: 0.18)
private let stepAccentUIColor = stepUIColor(light: (0.075, 0.445, 0.375), dark: (0.240, 0.820, 0.690))
private let stepEnergyUIColor = stepUIColor(light: (0.910, 0.390, 0.210), dark: (1.000, 0.520, 0.260))
private let stepDistanceUIColor = stepUIColor(light: (0.200, 0.390, 0.760), dark: (0.430, 0.640, 1.000))
private let stepWarningUIColor = stepUIColor(light: (0.760, 0.290, 0.180), dark: (1.000, 0.470, 0.370))
private let stepSurfaceUIColor = stepUIColor(light: (1.000, 1.000, 1.000), dark: (0.105, 0.112, 0.108))

extension Color {
    static let stepBackground = Color(uiColor: stepBackgroundUIColor)
    static let stepInk = Color(uiColor: stepInkUIColor)
    static let stepMuted = Color(uiColor: stepMutedUIColor)
    static let stepAxis = Color(uiColor: stepAxisUIColor)
    static let stepAxisGrid = Color(uiColor: stepAxisGridUIColor)
    static let stepAccent = Color(uiColor: stepAccentUIColor)
    static let stepEnergy = Color(uiColor: stepEnergyUIColor)
    static let stepDistance = Color(uiColor: stepDistanceUIColor)
    static let stepWarning = Color(uiColor: stepWarningUIColor)
    static let stepSurface = Color(uiColor: stepSurfaceUIColor)
}
#else
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
#endif

#if canImport(UIKit)
enum StepReceiptChrome {
    @MainActor
    static func configure() {
        let navigation = UINavigationBarAppearance()
        navigation.configureWithOpaqueBackground()
        navigation.backgroundColor = stepBackgroundUIColor
        navigation.titleTextAttributes = [.foregroundColor: stepInkUIColor]
        navigation.largeTitleTextAttributes = [.foregroundColor: stepInkUIColor]
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().compactAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = navigation

        let tabBar = UITabBarAppearance()
        tabBar.configureWithOpaqueBackground()
        tabBar.backgroundColor = stepSurfaceUIColor
        tabBar.shadowColor = UIColor.black.withAlphaComponent(0.12)

        let normalAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: stepMutedUIColor]
        let selectedAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: stepAccentUIColor]
        for itemAppearance in [
            tabBar.stackedLayoutAppearance,
            tabBar.inlineLayoutAppearance,
            tabBar.compactInlineLayoutAppearance
        ] {
            itemAppearance.normal.iconColor = stepMutedUIColor
            itemAppearance.normal.titleTextAttributes = normalAttributes
            itemAppearance.selected.iconColor = stepAccentUIColor
            itemAppearance.selected.titleTextAttributes = selectedAttributes
        }

        UITabBar.appearance().standardAppearance = tabBar
        UITabBar.appearance().scrollEdgeAppearance = tabBar
        UITabBar.appearance().tintColor = stepAccentUIColor
        UITabBar.appearance().unselectedItemTintColor = stepMutedUIColor
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
