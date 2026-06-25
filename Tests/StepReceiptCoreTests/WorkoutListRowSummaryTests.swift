import Foundation
import Testing
@testable import StepReceiptCore

struct WorkoutListRowSummaryTests {
    private let calendar = Calendar(identifier: .gregorian)

    @Test
    func testBuildIncludesHeartRateAndBurnRate() {
        let workout = stairWorkout(
            id: "current",
            day: 25,
            energy: 620,
            durationMinutes: 62,
            heartRate: 142
        )

        let summary = WorkoutListRowSummaryBuilder.build(
            workout: workout,
            peers: [workout],
            lastSession: nil
        )

        #expect(summary.averageHeartRateText == "143 bpm")
        #expect(summary.burnRateText == "10.0 kcal/min")
        #expect(summary.insightText == "First in window")
    }

    @Test
    func testBurnRateInsightVersusLastSession() {
        let last = stairWorkout(id: "last", day: 24, energy: 631, durationMinutes: 61, heartRate: 140)
        let current = stairWorkout(id: "current", day: 25, energy: 620, durationMinutes: 62, heartRate: 142)
        let peers = [last, current]

        let summary = WorkoutListRowSummaryBuilder.build(
            workout: current,
            peers: peers,
            lastSession: last
        )

        #expect(summary.insightText?.contains("burn vs last") == true)
        #expect(summary.insightText?.contains("%") == true)
    }

    @Test
    func testNearAverageWhenDeltasAreSmall() {
        let last = stairWorkout(id: "last", day: 24, energy: 620, durationMinutes: 62, heartRate: 142)
        let current = stairWorkout(id: "current", day: 25, energy: 621, durationMinutes: 62, heartRate: 143)
        let peers = [last, current]

        let summary = WorkoutListRowSummaryBuilder.build(
            workout: current,
            peers: peers,
            lastSession: last
        )

        #expect(summary.insightText == "Near avg")
        #expect(summary.insightTone == .neutral)
    }

    @Test
    func testOmitsHeartRateWhenSamplesMissing() {
        let workout = stairWorkout(id: "current", day: 25, energy: 620, durationMinutes: 62, heartRate: nil)
        let summary = WorkoutListRowSummaryBuilder.build(
            workout: workout,
            peers: [],
            lastSession: nil
        )

        #expect(summary.averageHeartRateText == nil)
        #expect(summary.burnRateText == "10.0 kcal/min")
    }

    @Test
    func testPeerAverageFallbackWhenNoLastSession() {
        let peerA = stairWorkout(id: "a", day: 20, energy: 500, durationMinutes: 50, heartRate: 130)
        let peerB = stairWorkout(id: "b", day: 22, energy: 700, durationMinutes: 70, heartRate: 150)
        let current = stairWorkout(id: "current", day: 25, energy: 800, durationMinutes: 60, heartRate: 145)

        let summary = WorkoutListRowSummaryBuilder.build(
            workout: current,
            peers: [peerA, peerB, current],
            lastSession: nil
        )

        #expect(summary.insightText?.contains("vs avg") == true)
    }

    private func stairWorkout(
        id: String,
        day: Int,
        energy: Double,
        durationMinutes: Double,
        heartRate: Double?
    ) -> WorkoutActivity {
        let start = calendar.date(from: DateComponents(year: 2026, month: 6, day: day, hour: 7, minute: 16))!
        let samples: [WorkoutHeartRateSample]
        if let heartRate {
            samples = [
                WorkoutHeartRateSample(timestamp: start.addingTimeInterval(300), beatsPerMinute: heartRate),
                WorkoutHeartRateSample(timestamp: start.addingTimeInterval(900), beatsPerMinute: heartRate + 2)
            ]
        } else {
            samples = []
        }

        return WorkoutActivity(
            sourceIdentifier: id,
            type: .stairClimbing,
            startDate: start,
            endDate: start.addingTimeInterval(durationMinutes * 60),
            durationMinutes: durationMinutes,
            activeEnergyKilocalories: energy,
            heartRateSamples: samples
        )
    }
}
