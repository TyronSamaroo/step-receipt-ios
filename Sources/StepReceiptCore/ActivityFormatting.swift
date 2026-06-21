import Foundation

public enum ActivityFormatting {
    public static func miles(from meters: Double) -> Double {
        max(0, meters) / 1_609.344
    }

    public static func kilometers(from meters: Double) -> Double {
        max(0, meters) / 1_000
    }

    public static func formattedDistance(from meters: Double, unit: DistanceUnit = .miles) -> String {
        switch unit {
        case .miles:
            return String(format: "%.2f mi", miles(from: meters))
        case .kilometers:
            return String(format: "%.2f km", kilometers(from: meters))
        }
    }

    public static func formattedMiles(from meters: Double) -> String {
        formattedDistance(from: meters, unit: .miles)
    }

    public static func formattedCalories(_ calories: Double) -> String {
        "\(Int(calories.rounded())) kcal"
    }

    public static func formattedMinutes(_ minutes: Double) -> String {
        if minutes < 60 {
            return "\(Int(minutes.rounded())) min"
        }
        let hours = Int(minutes / 60)
        let remainder = Int(minutes.rounded()) % 60
        return remainder == 0 ? "\(hours) hr" : "\(hours) hr \(remainder) min"
    }

    public static func formattedDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds.rounded()))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        }
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    public static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func shortHourLabel(for date: Date, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        if hour == 0 { return "12a" }
        if hour < 12 { return "\(hour)a" }
        if hour == 12 { return "12p" }
        return "\(hour - 12)p"
    }

    public static func compactHourlyDetail(
        steps: Int,
        distanceMeters: Double,
        activeEnergyKilocalories: Double,
        unit: DistanceUnit
    ) -> String {
        let parts = formattedHourlyRowParts(
            steps: steps,
            distanceMeters: distanceMeters,
            activeEnergyKilocalories: activeEnergyKilocalories,
            unit: unit
        )
        return "\(parts.stepsText) steps · \(parts.distanceText) · \(parts.caloriesText)"
    }

    public struct HourlyRowParts: Equatable, Sendable {
        public let stepsText: String
        public let distanceText: String
        public let caloriesText: String

        public init(stepsText: String, distanceText: String, caloriesText: String) {
            self.stepsText = stepsText
            self.distanceText = distanceText
            self.caloriesText = caloriesText
        }
    }

    public static func formattedHourlyRowParts(
        steps: Int,
        distanceMeters: Double,
        activeEnergyKilocalories: Double,
        unit: DistanceUnit
    ) -> HourlyRowParts {
        HourlyRowParts(
            stepsText: steps.formatted(),
            distanceText: formattedDistance(from: distanceMeters, unit: unit),
            caloriesText: formattedCalories(activeEnergyKilocalories)
        )
    }

    public static func formattedActiveWindowLabel(
        start: Date,
        end: Date,
        calendar: Calendar = .current
    ) -> String {
        let startLabel = shortHourLabel(for: start, calendar: calendar)
        let endLabel = shortHourLabel(for: end, calendar: calendar)
        return "Active \(startLabel)–\(endLabel)"
    }
}
