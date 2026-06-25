import Foundation
import Testing
@testable import StepReceiptCore

struct WorkoutExportBuilderTests {
    private let calendar = Calendar(identifier: .gregorian)

    @Test
    func testSingleWorkoutHeartRateCSVIncludesZoneAndElapsed() {
        let start = calendar.date(from: DateComponents(year: 2026, month: 6, day: 25, hour: 7, minute: 15))!
        let workout = WorkoutActivity(
            sourceIdentifier: "stairs-1",
            type: .stairClimbing,
            startDate: start,
            endDate: start.addingTimeInterval(20 * 60),
            durationMinutes: 20,
            heartRateSamples: [
                WorkoutHeartRateSample(timestamp: start.addingTimeInterval(300), beatsPerMinute: 140),
                WorkoutHeartRateSample(timestamp: start.addingTimeInterval(900), beatsPerMinute: 152)
            ]
        )

        let csv = WorkoutExportBuilder.heartRateSamplesCSV(workout: workout)
        let lines = csv.split(separator: "\n")

        #expect(lines.first == "timestamp,bpm,elapsed_min,zone")
        #expect(lines.count == 3)
        #expect(csv.contains(",140,"))
        #expect(csv.contains(",152,"))
        #expect(csv.contains("Zone"))
    }

    @Test
    func testBulkSummaryIncludesFadeAndBurnComparison() {
        let start = calendar.date(from: DateComponents(year: 2026, month: 6, day: 25, hour: 7))!
        let last = stairWorkout(
            id: "last",
            start: start.addingTimeInterval(-86_400),
            energy: 600,
            durationMinutes: 60,
            heartRates: Array(repeating: 140, count: 12)
        )
        let current = stairWorkout(
            id: "current",
            start: start,
            energy: 500,
            durationMinutes: 50,
            heartRates: [150, 150, 150, 145, 145, 145, 130, 130, 130]
        )

        let rows = [
            WorkoutExportRowContext(
                workout: current,
                analysis: WorkoutHeartRateAnalyzer.analyze(workout: current),
                vsLastBurnPercent: WorkoutExportBuilder.burnRatePercentChange(current: current, baseline: last)
            )
        ]

        let export = WorkoutExportBuilder.bulkExport(rows: rows, includeHeartRateSamples: true)
        let summaryLines = export.summaryCSV.split(separator: "\n")
        let sampleLines = export.heartRateSamplesCSV?.split(separator: "\n") ?? []

        #expect(summaryLines.first == "workout_id,date,type,tag,duration_min,calories,cal_per_min,steps,distance_m,avg_hr,min_hr,max_hr,peak_hr_bpm,peak_hr_time,fade_bpm,dominant_zone,vs_last_burn_pct,source,environment")
        #expect(summaryLines.count == 2)
        #expect(summaryLines[1].contains("Stair"))
        #expect(sampleLines.first == "workout_id,timestamp,bpm,elapsed_min,zone")
        #expect(sampleLines.count > 1)
    }

    private func stairWorkout(
        id: String,
        start: Date,
        energy: Double,
        durationMinutes: Double,
        heartRates: [Double]
    ) -> WorkoutActivity {
        let samples = heartRates.enumerated().map { index, bpm in
            WorkoutHeartRateSample(
                timestamp: start.addingTimeInterval(Double(index * 300)),
                beatsPerMinute: bpm
            )
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
