import Foundation
import StepReceiptCore

enum CheckFailure: Error, CustomStringConvertible {
    case failed(String)
    case invalidDate(String)

    var description: String {
        switch self {
        case .failed(let message): message
        case .invalidDate(let iso): "Invalid ISO date: \(iso)"
        }
    }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw CheckFailure.failed(message)
    }
}

func date(_ iso: String) throws -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    guard let date = formatter.date(from: iso) else {
        throw CheckFailure.invalidDate(iso)
    }
    return date
}

func bucket(
    _ isoStart: String,
    steps: Int = 0,
    distance: Double = 0,
    energy: Double = 0,
    flights: Int = 0
) throws -> HealthMetricBucket {
    let start = try date(isoStart)
    return HealthMetricBucket(
        startDate: start,
        endDate: start.addingTimeInterval(3_600),
        steps: steps,
        distanceMeters: distance,
        activeEnergyKilocalories: energy,
        flightsClimbed: flights
    )
}

func workout(_ isoStart: String, type: ActivityKind) throws -> WorkoutActivity {
    let start = try date(isoStart)
    return WorkoutActivity(
        sourceIdentifier: isoStart,
        type: type,
        startDate: start,
        endDate: start.addingTimeInterval(45 * 60),
        distanceMeters: type == .running ? 5_000 : nil,
        activeEnergyKilocalories: type == .running ? 420 : 160
    )
}

func summary(_ isoDayStart: String, steps: Int, goals: UserGoals) throws -> DailyActivitySummary {
    let start = try date(isoDayStart)
    return DailyActivitySummary(
        dateStart: start,
        steps: steps,
        distanceMeters: Double(steps) * 0.75,
        activeEnergyKilocalories: Double(steps) * 0.04,
        flightsClimbed: steps / 2_000,
        workoutMinutes: steps >= goals.stepsPerDay ? 35 : 0,
        buckets: [],
        workouts: [],
        goals: goals
    )
}

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(secondsFromGMT: 0)!
let engine = InsightEngine(calendar: calendar)
let goals = UserGoals(stepsPerDay: 10_000)

let aggregateBuckets = [
    try bucket("2026-06-10T08:00:00Z", steps: 1_200, distance: 900, energy: 35, flights: 1),
    try bucket("2026-06-10T12:00:00Z", steps: 2_300, distance: 1_700, energy: 90, flights: 4),
    try bucket("2026-06-11T08:00:00Z", steps: 9_999, distance: 9_999, energy: 9_999, flights: 9)
]
let run = WorkoutActivity(
    sourceIdentifier: "w1",
    type: .running,
    startDate: try date("2026-06-10T18:00:00Z"),
    endDate: try date("2026-06-10T18:45:00Z"),
    distanceMeters: 5_000,
    activeEnergyKilocalories: 410
)
let aggregate = engine.aggregateDay(
    containing: try date("2026-06-10T00:00:00Z"),
    buckets: aggregateBuckets,
    workouts: [run],
    goals: goals
)
try expect(aggregate.steps == 3_500, "aggregate steps should sum same-day buckets")
try expect(aggregate.distanceMeters == 2_600, "aggregate distance should sum same-day buckets")
try expect(aggregate.activeEnergyKilocalories == 125, "aggregate energy should sum same-day buckets")
try expect(aggregate.flightsClimbed == 5, "aggregate flights should sum same-day buckets")
try expect(aggregate.workoutMinutes == 45, "aggregate should include workout minutes")

let summaries = [
    try summary("2026-05-30T00:00:00Z", steps: 8_000, goals: goals),
    try summary("2026-05-31T00:00:00Z", steps: 12_000, goals: goals),
    try summary("2026-06-01T00:00:00Z", steps: 15_000, goals: goals),
    try summary("2026-06-02T00:00:00Z", steps: 10_500, goals: goals)
]
let receipt = engine.receipt(
    for: summaries,
    goals: goals,
    now: try date("2026-06-02T18:00:00Z")
)
try expect(receipt.totalSteps == 45_500, "receipt total steps should sum period")
try expect(receipt.dailyAverageSteps == 11_375, "receipt average should round correctly")
try expect(receipt.bestDay?.steps == 15_000, "receipt should find best day")
try expect(receipt.bestMonth?.steps == 25_500, "receipt should find best month")
try expect(receipt.currentStepGoalStreakDays == 3, "receipt should compute current streak")
try expect(receipt.stepGoalCompletionRate == 0.75, "receipt should compute goal completion rate")

let projectedReceipt = engine.receipt(
    for: [try summary("2026-06-10T00:00:00Z", steps: 5_000, goals: goals)],
    goals: goals,
    now: try date("2026-06-10T12:00:00Z")
)
try expect(projectedReceipt.projectedStepsToday == 10_000, "projection should use elapsed day")

let filtered = engine.filterWorkouts(
    [
        try workout("2026-06-08T10:00:00Z", type: .walking),
        try workout("2026-06-09T10:00:00Z", type: .running),
        try workout("2026-06-10T10:00:00Z", type: .running)
    ],
    kind: .running,
    startDate: try date("2026-06-09T00:00:00Z"),
    endDate: try date("2026-06-09T23:59:59Z")
)
try expect(filtered.count == 1, "workout filter should respect kind and dates")

let boundarySummaries = engine.dailySummaries(
    from: [
        try bucket("2026-06-09T23:30:00Z", steps: 900),
        try bucket("2026-06-10T00:15:00Z", steps: 1_100)
    ],
    workouts: [],
    startDate: try date("2026-06-09T00:00:00Z"),
    endDate: try date("2026-06-10T00:00:00Z"),
    goals: goals
)
try expect(boundarySummaries.map(\.steps) == [900, 1_100], "daily summaries should respect calendar boundaries")

let syncedRecord = engine.syncedRecord(from: aggregate, updatedAt: try date("2026-06-10T20:00:00Z"))
try expect(syncedRecord.dayKey == "2026-06-10", "sync record should use day key")
try expect(syncedRecord.workoutCount == 1, "sync record should include aggregate workout count")

let defaultPreferences = UserPreferences(displayName: "   ", distanceUnit: .kilometers, visibleDashboardMetrics: [])
try expect(defaultPreferences.displayName == "You", "preferences should normalize blank display names")
try expect(defaultPreferences.distanceUnit == .kilometers, "preferences should preserve selected distance unit")
try expect(defaultPreferences.visibleDashboardMetrics == DashboardMetric.allCases, "preferences should restore all metrics when empty")
try expect(ActivityFormatting.formattedDistance(from: 1_609.344, unit: .miles) == "1.00 mi", "distance formatter should support miles")
try expect(ActivityFormatting.formattedDistance(from: 1_000, unit: .kilometers) == "1.00 km", "distance formatter should support kilometers")

let competitionEngine = CompetitionEngine(calendar: calendar)
let currentUser = CompetitorProfile(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
    displayName: "You",
    initials: "Y"
)
let friend = CompetitorProfile(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
    displayName: "Maya",
    initials: "M"
)
let competitionEntries = [
    CompetitionEntry(
        competitor: currentUser,
        dayKey: "2026-06-10",
        steps: 8_000,
        distanceMeters: 6_000,
        activeEnergyKilocalories: 320,
        workoutMinutes: 35,
        updatedAt: try date("2026-06-10T12:00:00Z")
    ),
    CompetitionEntry(
        competitor: friend,
        dayKey: "2026-06-10",
        steps: 9_250,
        distanceMeters: 7_000,
        activeEnergyKilocalories: 360,
        workoutMinutes: 22,
        updatedAt: try date("2026-06-10T12:00:00Z")
    ),
    CompetitionEntry(
        competitor: friend,
        dayKey: "2026-05-10",
        steps: 99_000,
        distanceMeters: 70_000,
        activeEnergyKilocalories: 4_000,
        workoutMinutes: 500,
        updatedAt: try date("2026-05-10T12:00:00Z")
    )
]
let competitionReceipt = competitionEngine.receipt(
    entries: competitionEntries,
    currentUserID: currentUser.id,
    window: .today,
    metric: .steps,
    now: try date("2026-06-10T18:00:00Z")
)
try expect(competitionReceipt.rows.count == 2, "competition should filter entries by window")
try expect(competitionReceipt.rows.first?.competitor.id == friend.id, "competition should rank highest score first")
try expect(competitionReceipt.currentUserRank == 2, "competition should expose current user rank")
try expect(competitionReceipt.gapToNextRank == 1_250, "competition should compute gap to next rank")
try expect(competitionReceipt.headline.contains("1,250"), "competition headline should include gap")

let tieBreakerFriend = CompetitorProfile(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
    displayName: "Alex",
    initials: "A"
)
let tieReceipt = competitionEngine.receipt(
    entries: [
        CompetitionEntry(
            competitor: currentUser,
            dayKey: "2026-06-10",
            steps: 5_000,
            distanceMeters: 3_000,
            activeEnergyKilocalories: 200,
            workoutMinutes: 10,
            updatedAt: try date("2026-06-10T12:00:00Z")
        ),
        CompetitionEntry(
            competitor: tieBreakerFriend,
            dayKey: "2026-06-10",
            steps: 5_000,
            distanceMeters: 3_000,
            activeEnergyKilocalories: 200,
            workoutMinutes: 10,
            updatedAt: try date("2026-06-10T12:00:00Z")
        )
    ],
    currentUserID: currentUser.id,
    window: .today,
    metric: .steps,
    now: try date("2026-06-10T18:00:00Z")
)
try expect(tieReceipt.rows.map(\.competitor.displayName) == ["Alex", "You"], "competition should tie-break by display name")

let weekReceipt = competitionEngine.receipt(
    entries: competitionEntries,
    currentUserID: currentUser.id,
    window: .week,
    metric: .steps,
    now: try date("2026-06-10T18:00:00Z")
)
try expect(weekReceipt.rows.first?.score == 9_250, "competition week window should exclude older months")

let monthReceipt = competitionEngine.receipt(
    entries: competitionEntries,
    currentUserID: currentUser.id,
    window: .month,
    metric: .steps,
    now: try date("2026-06-10T18:00:00Z")
)
try expect(monthReceipt.rows.first?.score == 9_250, "competition month window should exclude previous month")

let missingUserReceipt = competitionEngine.receipt(
    entries: [competitionEntries[1]],
    currentUserID: currentUser.id,
    window: .today,
    metric: .steps,
    now: try date("2026-06-10T18:00:00Z")
)
try expect(missingUserReceipt.currentUserRank == nil, "competition should handle missing current user")
try expect(missingUserReceipt.headline == "Connect summaries to start a friendly board.", "missing current user should get setup headline")

let encodedCompetitionEntry = try JSONEncoder().encode(competitionEntries[0])
let encodedCompetitionText = String(data: encodedCompetitionEntry, encoding: .utf8) ?? ""
try expect(encodedCompetitionText.contains("steps"), "competition entry should serialize aggregate steps")
try expect(!encodedCompetitionText.contains("sourceIdentifier"), "competition entry should not serialize raw source identifiers")
try expect(!encodedCompetitionText.contains("sourceName"), "competition entry should not serialize raw source names")

print("StepReceiptCoreCheck passed")
