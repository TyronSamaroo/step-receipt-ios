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
}
