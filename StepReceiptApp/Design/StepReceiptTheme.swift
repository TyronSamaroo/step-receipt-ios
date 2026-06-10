import SwiftUI

extension Color {
    static let stepBackground = Color(red: 0.965, green: 0.972, blue: 0.956)
    static let stepInk = Color(red: 0.075, green: 0.090, blue: 0.086)
    static let stepMuted = Color(red: 0.420, green: 0.455, blue: 0.440)
    static let stepAccent = Color(red: 0.110, green: 0.520, blue: 0.440)
    static let stepEnergy = Color(red: 0.910, green: 0.390, blue: 0.210)
    static let stepDistance = Color(red: 0.200, green: 0.390, blue: 0.760)
    static let stepWarning = Color(red: 0.760, green: 0.290, blue: 0.180)
    static let stepSurface = Color.white
}

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
