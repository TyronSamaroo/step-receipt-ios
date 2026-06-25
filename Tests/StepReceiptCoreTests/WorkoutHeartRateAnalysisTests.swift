import Foundation
import Testing
@testable import StepReceiptCore

struct WorkoutHeartRateAnalysisTests {
    private let calendar = Calendar(identifier: .gregorian)

    @Test
    func testDetectsPeakAndFade() {
        let start = calendar.date(from: DateComponents(year: 2026, month: 6, day: 25, hour: 7))!
        var samples: [WorkoutHeartRateSample] = []
        for minute in 0..<30 {
            let bpm: Double
            if minute < 10 {
                bpm = 150
            } else if minute < 20 {
                bpm = 145
            } else {
                bpm = 132
            }
            samples.append(
                WorkoutHeartRateSample(
                    timestamp: start.addingTimeInterval(Double(minute * 60)),
                    beatsPerMinute: bpm
                )
            )
        }

        let workout = WorkoutActivity(
            sourceIdentifier: "fade",
            type: .stairClimbing,
            startDate: start,
            endDate: start.addingTimeInterval(30 * 60),
            durationMinutes: 30,
            activeEnergyKilocalories: 500,
            heartRateSamples: samples
        )

        let analysis = WorkoutHeartRateAnalyzer.analyze(workout: workout)

        #expect(analysis.peakBPM == 150)
        #expect(analysis.fadeDeltaBPM != nil)
        #expect(analysis.storyLines.contains { $0.contains("Peak 150") })
        #expect(analysis.storyLines.contains { $0.contains("Faded") })
    }

    @Test
    func testSteadyStateWhenMiddleSegmentIsFlat() {
        let start = calendar.date(from: DateComponents(year: 2026, month: 6, day: 25, hour: 8))!
        let samples = (0..<18).map { index in
            WorkoutHeartRateSample(
                timestamp: start.addingTimeInterval(Double(index * 120)),
                beatsPerMinute: 138 + Double(index % 2)
            )
        }

        let workout = WorkoutActivity(
            sourceIdentifier: "steady",
            type: .stairClimbing,
            startDate: start,
            endDate: start.addingTimeInterval(36 * 60),
            durationMinutes: 36,
            heartRateSamples: samples
        )

        let analysis = WorkoutHeartRateAnalyzer.analyze(workout: workout)

        #expect(analysis.isSteadyState)
        #expect(analysis.storyLines.contains { $0.contains("Steady around") })
    }

    @Test
    func testEmptyWhenNoSamples() {
        let start = calendar.date(from: DateComponents(year: 2026, month: 6, day: 25, hour: 9))!
        let workout = WorkoutActivity(
            sourceIdentifier: "empty",
            type: .strengthTraining,
            startDate: start,
            endDate: start.addingTimeInterval(45 * 60),
            durationMinutes: 45
        )

        let analysis = WorkoutHeartRateAnalyzer.analyze(workout: workout)

        #expect(analysis.storyLines.isEmpty)
        #expect(!analysis.hasContent)
    }
}
