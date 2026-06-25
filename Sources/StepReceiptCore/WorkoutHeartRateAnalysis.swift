import Foundation

public struct WorkoutHeartRateAnalysis: Equatable, Sendable {
    public let averageBPM: Double?
    public let peakBPM: Double?
    public let peakElapsedMinutes: Double?
    public let fadeDeltaBPM: Double?
    public let fadeSegmentMinutes: Double?
    public let isSteadyState: Bool
    public let storyLines: [String]

    public init(
        averageBPM: Double? = nil,
        peakBPM: Double? = nil,
        peakElapsedMinutes: Double? = nil,
        fadeDeltaBPM: Double? = nil,
        fadeSegmentMinutes: Double? = nil,
        isSteadyState: Bool = false,
        storyLines: [String] = []
    ) {
        self.averageBPM = averageBPM
        self.peakBPM = peakBPM
        self.peakElapsedMinutes = peakElapsedMinutes
        self.fadeDeltaBPM = fadeDeltaBPM
        self.fadeSegmentMinutes = fadeSegmentMinutes
        self.isSteadyState = isSteadyState
        self.storyLines = storyLines
    }

    public var hasContent: Bool {
        !storyLines.isEmpty
    }
}

public enum WorkoutHeartRateAnalyzer {
    private static let fadeThresholdBPM = 5.0
    private static let steadyStateStandardDeviationBPM = 6.0

    public static func analyze(workout: WorkoutActivity) -> WorkoutHeartRateAnalysis {
        let samples = workout.heartRateSamples.sorted { $0.timestamp < $1.timestamp }
        guard !samples.isEmpty else {
            return WorkoutHeartRateAnalysis()
        }

        let sessionAverage = workout.averageHeartRateBPM
        let peakSample = samples.max(by: { $0.beatsPerMinute < $1.beatsPerMinute })
        let peakBPM = peakSample?.beatsPerMinute
        let peakElapsedMinutes = peakSample.map {
            max(0, $0.timestamp.timeIntervalSince(workout.startDate) / 60)
        }

        let segmentSize = max(1, samples.count / 3)
        let firstThird = samples.prefix(segmentSize)
        let lastThird = samples.suffix(segmentSize)
        let firstAverage = segmentAverageBPM(for: firstThird)
        let lastAverage = segmentAverageBPM(for: lastThird)
        let fadeDelta = firstAverage.flatMap { first in
            lastAverage.map { first - $0 }
        }

        let middleSamples = samples.dropFirst(segmentSize).dropLast(segmentSize)
        let isSteadyState = segmentStandardDeviation(for: middleSamples).map { $0 <= steadyStateStandardDeviationBPM } ?? false

        let fadeSegmentMinutes = workout.durationMinutes / 3
        var storyLines: [String] = []

        if let sessionAverage {
            storyLines.append("Avg \(Int(sessionAverage.rounded())) bpm")
        }

        if let peakBPM, let peakElapsedMinutes {
            let peakLabel = formattedElapsedMinutes(peakElapsedMinutes)
            storyLines.append("Peak \(Int(peakBPM.rounded())) at \(peakLabel)")
        }

        if let fadeDelta, fadeDelta >= fadeThresholdBPM {
            storyLines.append(
                "Faded −\(Int(fadeDelta.rounded())) bpm in final \(Int(fadeSegmentMinutes.rounded())) min"
            )
        } else if isSteadyState, let sessionAverage {
            storyLines.append("Steady around \(Int(sessionAverage.rounded())) bpm")
        }

        return WorkoutHeartRateAnalysis(
            averageBPM: sessionAverage,
            peakBPM: peakBPM,
            peakElapsedMinutes: peakElapsedMinutes,
            fadeDeltaBPM: fadeDelta,
            fadeSegmentMinutes: fadeSegmentMinutes,
            isSteadyState: isSteadyState,
            storyLines: Array(storyLines.prefix(3))
        )
    }

    private static func segmentAverageBPM<S: Sequence>(for samples: S) -> Double? where S.Element == WorkoutHeartRateSample {
        let values = samples.map(\.beatsPerMinute)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func segmentStandardDeviation<S: Sequence>(for samples: S) -> Double? where S.Element == WorkoutHeartRateSample {
        let values = samples.map(\.beatsPerMinute)
        guard values.count >= 2 else { return nil }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { partial, value in
            let delta = value - mean
            return partial + delta * delta
        } / Double(values.count)
        return sqrt(variance)
    }

    private static func formattedElapsedMinutes(_ minutes: Double) -> String {
        let totalMinutes = max(0, Int(minutes.rounded()))
        if totalMinutes < 60 {
            return "\(totalMinutes) min"
        }
        let hours = totalMinutes / 60
        let remainder = totalMinutes % 60
        if remainder == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(remainder)m"
    }
}
