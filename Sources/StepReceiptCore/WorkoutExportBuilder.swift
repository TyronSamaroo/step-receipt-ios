import Foundation

public struct WorkoutBulkExport: Equatable, Sendable {
    public let summaryCSV: String
    public let heartRateSamplesCSV: String?

    public init(summaryCSV: String, heartRateSamplesCSV: String? = nil) {
        self.summaryCSV = summaryCSV
        self.heartRateSamplesCSV = heartRateSamplesCSV
    }
}

public struct WorkoutExportRowContext: Sendable {
    public let workout: WorkoutActivity
    public let analysis: WorkoutHeartRateAnalysis
    public let vsLastBurnPercent: Double?

    public init(
        workout: WorkoutActivity,
        analysis: WorkoutHeartRateAnalysis,
        vsLastBurnPercent: Double? = nil
    ) {
        self.workout = workout
        self.analysis = analysis
        self.vsLastBurnPercent = vsLastBurnPercent
    }
}

public enum WorkoutExportBuilder {
    public static func heartRateSamplesCSV(
        workout: WorkoutActivity,
        zoneConfiguration: HeartRateZoneConfiguration = .default
    ) -> String {
        var lines = ["timestamp,bpm,elapsed_min,zone"]
        for sample in workout.heartRateSamples {
            let elapsed = sample.timestamp.timeIntervalSince(workout.startDate) / 60
            let zone = zoneConfiguration.template(for: sample.beatsPerMinute).title
            lines.append(
                [
                    csvField(formattedTimestamp(sample.timestamp)),
                    csvField(Int(sample.beatsPerMinute.rounded())),
                    csvField(String(format: "%.2f", elapsed)),
                    csvField(zone)
                ].joined(separator: ",")
            )
        }
        return lines.joined(separator: "\n")
    }

    public static func bulkExport(
        rows: [WorkoutExportRowContext],
        includeHeartRateSamples: Bool,
        zoneConfiguration: HeartRateZoneConfiguration = .default
    ) -> WorkoutBulkExport {
        let summaryCSV = summaryCSV(for: rows)
        let heartRateSamplesCSV = includeHeartRateSamples
            ? combinedHeartRateSamplesCSV(for: rows.map(\.workout), zoneConfiguration: zoneConfiguration)
            : nil
        return WorkoutBulkExport(summaryCSV: summaryCSV, heartRateSamplesCSV: heartRateSamplesCSV)
    }

    public static func summaryCSV(for rows: [WorkoutExportRowContext]) -> String {
        var lines = [
            "date,type,duration_min,calories,cal_per_min,avg_hr,min_hr,max_hr,fade_bpm,vs_last_burn_pct"
        ]

        for row in rows {
            let workout = row.workout
            let calories = workout.activeEnergyKilocalories
            let calPerMin = calories.flatMap { burn in
                workout.durationMinutes > 0 ? burn / workout.durationMinutes : nil
            }
            let fade = row.analysis.fadeDeltaBPM.flatMap { delta in
                delta >= 5 ? Int(-delta.rounded()) : nil
            }

            lines.append(
                [
                    csvField(formattedTimestamp(workout.startDate)),
                    csvField(workout.displayTitle),
                    csvField(String(format: "%.1f", workout.durationMinutes)),
                    csvField(calories.map { String(format: "%.0f", $0) }),
                    csvField(calPerMin.map { String(format: "%.1f", $0) }),
                    csvField(workout.averageHeartRateBPM.map { Int($0.rounded()) }),
                    csvField(workout.minHeartRateBPM.map { Int($0.rounded()) }),
                    csvField(workout.maxHeartRateBPM.map { Int($0.rounded()) }),
                    csvField(fade),
                    csvField(row.vsLastBurnPercent.map { String(Int($0.rounded())) })
                ].joined(separator: ",")
            )
        }

        return lines.joined(separator: "\n")
    }

    public static func burnRatePercentChange(current: WorkoutActivity, baseline: WorkoutActivity) -> Double? {
        guard let currentBurn = current.activeEnergyKilocalories,
              let baselineBurn = baseline.activeEnergyKilocalories,
              current.durationMinutes > 0,
              baseline.durationMinutes > 0 else {
            return nil
        }

        let currentRate = currentBurn / current.durationMinutes
        let baselineRate = baselineBurn / baseline.durationMinutes
        guard baselineRate > 0 else { return nil }
        return ((currentRate - baselineRate) / baselineRate) * 100
    }

    private static func combinedHeartRateSamplesCSV(
        for workouts: [WorkoutActivity],
        zoneConfiguration: HeartRateZoneConfiguration
    ) -> String {
        var lines = ["workout_id,timestamp,bpm,elapsed_min,zone"]
        for workout in workouts where !workout.heartRateSamples.isEmpty {
            for sample in workout.heartRateSamples {
                let elapsed = sample.timestamp.timeIntervalSince(workout.startDate) / 60
                let zone = zoneConfiguration.template(for: sample.beatsPerMinute).title
                lines.append(
                    [
                        csvField(workout.sourceIdentifier),
                        csvField(formattedTimestamp(sample.timestamp)),
                        csvField(Int(sample.beatsPerMinute.rounded())),
                        csvField(String(format: "%.2f", elapsed)),
                        csvField(zone)
                    ].joined(separator: ",")
                )
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func formattedTimestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private static func csvField(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "" }
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private static func csvField(_ value: Int?) -> String {
        guard let value else { return "" }
        return String(value)
    }
}
