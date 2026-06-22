import Foundation

public struct CompetitionEngine: Sendable {
    public let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func entry(
        from summary: DailyActivitySummary,
        competitor: CompetitorProfile,
        updatedAt: Date = Date()
    ) -> CompetitionEntry {
        CompetitionEntry(
            competitor: competitor,
            dayKey: ActivityFormatting.dayKey(for: summary.dateStart, calendar: calendar),
            steps: summary.steps,
            distanceMeters: summary.distanceMeters,
            activeEnergyKilocalories: summary.activeEnergyKilocalories,
            workoutMinutes: summary.workoutMinutes,
            updatedAt: updatedAt
        )
    }

    public func entries(
        from checkIns: [LocalCompetitionCheckIn],
        competitors: [CompetitorProfile]
    ) -> [CompetitionEntry] {
        var competitorsByID: [UUID: CompetitorProfile] = [:]
        for competitor in competitors {
            competitorsByID[competitor.id] = competitor
        }
        return checkIns.compactMap { checkIn in
            guard let competitor = competitorsByID[checkIn.competitorID] else { return nil }
            return CompetitionEntry(
                competitor: competitor,
                dayKey: checkIn.dayKey,
                steps: checkIn.steps,
                distanceMeters: checkIn.distanceMeters,
                activeEnergyKilocalories: checkIn.activeEnergyKilocalories,
                workoutMinutes: checkIn.workoutMinutes,
                updatedAt: checkIn.updatedAt
            )
        }
    }

    public func receipt(
        entries: [CompetitionEntry],
        currentUserID: UUID,
        window: CompetitionWindow,
        metric: CompetitionMetric,
        now: Date = Date()
    ) -> CompetitionReceipt {
        let filteredEntries = entries.filter { isEntry($0, in: window, now: now) }
        let grouped = Dictionary(grouping: filteredEntries, by: \.competitor.id)
        let unrankedRows = grouped.compactMap { _, competitorEntries -> LeaderboardRow? in
            guard let competitor = competitorEntries.first?.competitor else { return nil }
            let steps = competitorEntries.reduce(0) { $0 + $1.steps }
            let distance = competitorEntries.reduce(0) { $0 + $1.distanceMeters }
            let energy = competitorEntries.reduce(0) { $0 + $1.activeEnergyKilocalories }
            let workoutMinutes = competitorEntries.reduce(0) { $0 + $1.workoutMinutes }
            let score = scoreForMetric(
                metric,
                steps: steps,
                distanceMeters: distance,
                activeEnergyKilocalories: energy,
                workoutMinutes: workoutMinutes
            )

            return LeaderboardRow(
                rank: 0,
                competitor: competitor,
                metric: metric,
                score: score,
                steps: steps,
                distanceMeters: distance,
                activeEnergyKilocalories: energy,
                workoutMinutes: workoutMinutes,
                isCurrentUser: competitor.id == currentUserID
            )
        }

        let rows = unrankedRows
            .sorted {
                if $0.score == $1.score {
                    return $0.competitor.displayName.localizedCaseInsensitiveCompare($1.competitor.displayName) == .orderedAscending
                }
                return $0.score > $1.score
            }
            .enumerated()
            .map { index, row in
                LeaderboardRow(
                    rank: index + 1,
                    competitor: row.competitor,
                    metric: row.metric,
                    score: row.score,
                    steps: row.steps,
                    distanceMeters: row.distanceMeters,
                    activeEnergyKilocalories: row.activeEnergyKilocalories,
                    workoutMinutes: row.workoutMinutes,
                    isCurrentUser: row.isCurrentUser
                )
            }

        let currentIndex = rows.firstIndex { $0.isCurrentUser }
        let gapToNextRank: Double?
        if let currentIndex, currentIndex > 0 {
            gapToNextRank = max(0, rows[currentIndex - 1].score - rows[currentIndex].score)
        } else {
            gapToNextRank = nil
        }

        return CompetitionReceipt(
            window: window,
            metric: metric,
            generatedAt: now,
            rows: rows,
            currentUserRank: currentIndex.map { $0 + 1 },
            gapToNextRank: gapToNextRank,
            headline: headline(rows: rows, currentUserID: currentUserID, metric: metric, gapToNextRank: gapToNextRank)
        )
    }

    public func sampleEntries(currentUserID: UUID, currentUserName: String, summaries: [DailyActivitySummary], now: Date = Date()) -> [CompetitionEntry] {
        let currentUser = CompetitorProfile(id: currentUserID, displayName: currentUserName, initials: initials(from: currentUserName), accentHex: "#1C856F")
        let friends = [
            CompetitorProfile(displayName: "Maya", initials: "M", accentHex: "#3364C3"),
            CompetitorProfile(displayName: "Chris", initials: "C", accentHex: "#E86332"),
            CompetitorProfile(displayName: "Jordan", initials: "J", accentHex: "#7A5CCF")
        ]

        var entries = summaries.map { entry(from: $0, competitor: currentUser, updatedAt: now) }
        for friendIndex in friends.indices {
            for summary in summaries.suffix(14) {
                let multiplier = 0.72 + (Double((friendIndex + 1) * 13 + calendar.component(.day, from: summary.dateStart) % 9) / 100)
                entries.append(
                    CompetitionEntry(
                        competitor: friends[friendIndex],
                        dayKey: ActivityFormatting.dayKey(for: summary.dateStart, calendar: calendar),
                        steps: Int(Double(summary.steps) * multiplier) + (friendIndex * 450),
                        distanceMeters: summary.distanceMeters * multiplier,
                        activeEnergyKilocalories: summary.activeEnergyKilocalories * multiplier,
                        workoutMinutes: summary.workoutMinutes * (friendIndex == 2 ? 1.25 : multiplier),
                        updatedAt: now
                    )
                )
            }
        }
        return entries
    }

    private func isEntry(_ entry: CompetitionEntry, in window: CompetitionWindow, now: Date) -> Bool {
        guard let entryDate = date(fromDayKey: entry.dayKey) else { return false }
        switch window {
        case .today:
            return calendar.isDate(entryDate, inSameDayAs: now)
        case .week:
            return calendar.isDate(entryDate, equalTo: now, toGranularity: .weekOfYear)
        case .month:
            return calendar.isDate(entryDate, equalTo: now, toGranularity: .month)
        }
    }


    private func scoreForMetric(
        _ metric: CompetitionMetric,
        steps: Int,
        distanceMeters: Double,
        activeEnergyKilocalories: Double,
        workoutMinutes: Double
    ) -> Double {
        switch metric {
        case .steps:
            return Double(steps)
        case .distance:
            return distanceMeters
        case .activeEnergy:
            return activeEnergyKilocalories
        case .workoutMinutes:
            return workoutMinutes
        }
    }

    private func headline(rows: [LeaderboardRow], currentUserID: UUID, metric: CompetitionMetric, gapToNextRank: Double?) -> String {
        guard let current = rows.first(where: { $0.competitor.id == currentUserID }) else {
            return "Connect summaries to start a friendly board."
        }
        if current.rank == 1 {
            return "You are leading on \(metric.displayName.lowercased())."
        }
        if let gapToNextRank {
            return "\(formattedScore(gapToNextRank, metric: metric)) to move up one spot."
        }
        return "You are ranked #\(current.rank) for \(metric.displayName.lowercased())."
    }

    private func formattedScore(_ score: Double, metric: CompetitionMetric) -> String {
        switch metric {
        case .steps:
            return "\(Int(score.rounded()).formatted()) steps"
        case .distance:
            return ActivityFormatting.formattedMiles(from: score)
        case .activeEnergy:
            return ActivityFormatting.formattedCalories(score)
        case .workoutMinutes:
            return ActivityFormatting.formattedMinutes(score)
        }
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        let value = letters.isEmpty ? "ME" : String(letters).uppercased()
        return String(value.prefix(2))
    }
}
