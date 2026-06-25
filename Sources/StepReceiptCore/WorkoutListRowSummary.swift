import Foundation

public enum WorkoutInsightTone: String, Codable, Equatable, Sendable {
    case neutral
    case up
    case down
}

public struct WorkoutListRowSummary: Equatable, Sendable {
    public let averageHeartRateText: String?
    public let burnRateText: String?
    public let insightText: String?
    public let insightTone: WorkoutInsightTone

    public init(
        averageHeartRateText: String? = nil,
        burnRateText: String? = nil,
        insightText: String? = nil,
        insightTone: WorkoutInsightTone = .neutral
    ) {
        self.averageHeartRateText = averageHeartRateText
        self.burnRateText = burnRateText
        self.insightText = insightText
        self.insightTone = insightTone
    }

    public var formattedLine: String {
        [averageHeartRateText, burnRateText, insightText]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    public var hasVisibleContent: Bool {
        !formattedLine.isEmpty
    }
}

public enum WorkoutListRowSummaryBuilder {
    private static let burnRateThresholdPercent = 3.0
    private static let heartRateThresholdBPM = 3.0

    public static func build(
        workout: WorkoutActivity,
        peers: [WorkoutActivity],
        lastSession: WorkoutActivity?
    ) -> WorkoutListRowSummary {
        let averageHeartRateText = workout.averageHeartRateBPM.map { "\(Int($0.rounded())) bpm" }
        let burnRateText = burnRateText(for: workout)

        let peerExcludingCurrent = peers.filter { $0.sourceIdentifier != workout.sourceIdentifier }
        let insight = insight(
            for: workout,
            lastSession: lastSession,
            peerExcludingCurrent: peerExcludingCurrent
        )

        return WorkoutListRowSummary(
            averageHeartRateText: averageHeartRateText,
            burnRateText: burnRateText,
            insightText: insight?.text,
            insightTone: insight?.tone ?? .neutral
        )
    }

    private static func burnRateText(for workout: WorkoutActivity) -> String? {
        guard let burn = workout.activeEnergyKilocalories, workout.durationMinutes > 0 else { return nil }
        return String(format: "%.1f kcal/min", burn / workout.durationMinutes)
    }

    private static func burnRate(for workout: WorkoutActivity) -> Double? {
        guard let burn = workout.activeEnergyKilocalories, workout.durationMinutes > 0 else { return nil }
        return burn / workout.durationMinutes
    }

    private static func averageBurnRate(in workouts: [WorkoutActivity]) -> Double? {
        let rates = workouts.compactMap { burnRate(for: $0) }
        guard !rates.isEmpty else { return nil }
        return rates.reduce(0, +) / Double(rates.count)
    }

    private static func averageHeartRate(in workouts: [WorkoutActivity]) -> Double? {
        let values = workouts.compactMap(\.averageHeartRateBPM)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func insight(
        for workout: WorkoutActivity,
        lastSession: WorkoutActivity?,
        peerExcludingCurrent: [WorkoutActivity]
    ) -> (text: String, tone: WorkoutInsightTone)? {
        if let lastSession {
            if let burnInsight = burnRateInsight(
                current: workout,
                baseline: lastSession,
                label: "last"
            ) {
                return burnInsight
            }

            if let heartRateInsight = heartRateInsight(
                current: workout,
                baseline: lastSession,
                label: "last"
            ) {
                return heartRateInsight
            }

            return ("Near avg", .neutral)
        }

        guard !peerExcludingCurrent.isEmpty else {
            return ("First in window", .neutral)
        }

        if let avgBurnRate = averageBurnRate(in: peerExcludingCurrent),
           let currentBurnRate = burnRate(for: workout),
           avgBurnRate > 0 {
            let percentChange = ((currentBurnRate - avgBurnRate) / avgBurnRate) * 100
            if abs(percentChange) >= burnRateThresholdPercent {
                return (
                    formattedPercentInsight(percentChange, metric: "burn", label: "avg"),
                    tone(for: percentChange)
                )
            }
        }

        if let currentHR = workout.averageHeartRateBPM,
           let avgHR = averageHeartRate(in: peerExcludingCurrent) {
            let delta = currentHR - avgHR
            if abs(delta) >= heartRateThresholdBPM {
                return (
                    formattedHeartRateInsight(delta, label: "avg"),
                    tone(for: delta)
                )
            }
        }

        return ("Near avg", .neutral)
    }

    private static func burnRateInsight(
        current: WorkoutActivity,
        baseline: WorkoutActivity,
        label: String
    ) -> (text: String, tone: WorkoutInsightTone)? {
        guard let currentRate = burnRate(for: current),
              let baselineRate = burnRate(for: baseline),
              baselineRate > 0 else { return nil }

        let percentChange = ((currentRate - baselineRate) / baselineRate) * 100
        guard abs(percentChange) >= burnRateThresholdPercent else { return nil }

        return (
            formattedPercentInsight(percentChange, metric: "burn", label: label),
            tone(for: percentChange)
        )
    }

    private static func heartRateInsight(
        current: WorkoutActivity,
        baseline: WorkoutActivity,
        label: String
    ) -> (text: String, tone: WorkoutInsightTone)? {
        guard let currentHR = current.averageHeartRateBPM,
              let baselineHR = baseline.averageHeartRateBPM else { return nil }

        let delta = currentHR - baselineHR
        guard abs(delta) >= heartRateThresholdBPM else { return nil }

        return (
            formattedHeartRateInsight(delta, label: label),
            tone(for: delta)
        )
    }

    private static func formattedPercentInsight(_ percentChange: Double, metric: String, label: String) -> String {
        let rounded = Int(percentChange.rounded())
        let signed = rounded == 0 ? "0" : (rounded > 0 ? "+\(rounded)" : "\(rounded)")
        _ = metric
        return "\(signed)% vs \(label)"
    }

    private static func formattedHeartRateInsight(_ delta: Double, label: String) -> String {
        let rounded = Int(delta.rounded())
        let signed = rounded == 0 ? "0" : (rounded > 0 ? "+\(rounded)" : "\(rounded)")
        return "\(signed) bpm vs \(label)"
    }

    private static func tone(for delta: Double) -> WorkoutInsightTone {
        if abs(delta) < 0.5 { return .neutral }
        return delta > 0 ? .up : .down
    }
}
