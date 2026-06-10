import Foundation

public enum CompetitionMetric: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case steps
    case distance
    case activeEnergy
    case workoutMinutes

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .steps: "Steps"
        case .distance: "Distance"
        case .activeEnergy: "Active Burn"
        case .workoutMinutes: "Workout Time"
        }
    }
}

public enum CompetitionWindow: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case today
    case week
    case month

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .today: "Today"
        case .week: "This Week"
        case .month: "This Month"
        }
    }
}

public struct CompetitorProfile: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var displayName: String
    public var initials: String
    public var accentHex: String

    public init(
        id: UUID = UUID(),
        displayName: String,
        initials: String? = nil,
        accentHex: String = "#1C856F"
    ) {
        self.id = id
        self.displayName = displayName
        self.initials = initials ?? Self.initials(from: displayName)
        self.accentHex = accentHex
    }

    private static func initials(from name: String) -> String {
        let letters = name
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
        let value = letters.isEmpty ? "FR" : String(letters).uppercased()
        return String(value.prefix(2))
    }
}

public struct CompetitionEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: String { "\(competitor.id.uuidString)-\(dayKey)" }

    public let competitor: CompetitorProfile
    public let dayKey: String
    public let steps: Int
    public let distanceMeters: Double
    public let activeEnergyKilocalories: Double
    public let workoutMinutes: Double
    public let updatedAt: Date

    public init(
        competitor: CompetitorProfile,
        dayKey: String,
        steps: Int,
        distanceMeters: Double,
        activeEnergyKilocalories: Double,
        workoutMinutes: Double,
        updatedAt: Date
    ) {
        self.competitor = competitor
        self.dayKey = dayKey
        self.steps = max(0, steps)
        self.distanceMeters = max(0, distanceMeters)
        self.activeEnergyKilocalories = max(0, activeEnergyKilocalories)
        self.workoutMinutes = max(0, workoutMinutes)
        self.updatedAt = updatedAt
    }
}

public struct LocalCompetitionCheckIn: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let competitorID: UUID
    public let dayKey: String
    public let steps: Int
    public let distanceMeters: Double
    public let activeEnergyKilocalories: Double
    public let workoutMinutes: Double
    public let updatedAt: Date

    public init(
        id: UUID = UUID(),
        competitorID: UUID,
        dayKey: String,
        steps: Int,
        distanceMeters: Double = 0,
        activeEnergyKilocalories: Double = 0,
        workoutMinutes: Double = 0,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.competitorID = competitorID
        self.dayKey = dayKey
        self.steps = max(0, steps)
        self.distanceMeters = max(0, distanceMeters)
        self.activeEnergyKilocalories = max(0, activeEnergyKilocalories)
        self.workoutMinutes = max(0, workoutMinutes)
        self.updatedAt = updatedAt
    }
}

public struct LeaderboardRow: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID { competitor.id }

    public let rank: Int
    public let competitor: CompetitorProfile
    public let metric: CompetitionMetric
    public let score: Double
    public let steps: Int
    public let distanceMeters: Double
    public let activeEnergyKilocalories: Double
    public let workoutMinutes: Double
    public let isCurrentUser: Bool

    public init(
        rank: Int,
        competitor: CompetitorProfile,
        metric: CompetitionMetric,
        score: Double,
        steps: Int,
        distanceMeters: Double,
        activeEnergyKilocalories: Double,
        workoutMinutes: Double,
        isCurrentUser: Bool
    ) {
        self.rank = rank
        self.competitor = competitor
        self.metric = metric
        self.score = max(0, score)
        self.steps = max(0, steps)
        self.distanceMeters = max(0, distanceMeters)
        self.activeEnergyKilocalories = max(0, activeEnergyKilocalories)
        self.workoutMinutes = max(0, workoutMinutes)
        self.isCurrentUser = isCurrentUser
    }
}

public struct CompetitionReceipt: Codable, Equatable, Sendable {
    public let window: CompetitionWindow
    public let metric: CompetitionMetric
    public let generatedAt: Date
    public let rows: [LeaderboardRow]
    public let currentUserRank: Int?
    public let gapToNextRank: Double?
    public let headline: String

    public init(
        window: CompetitionWindow,
        metric: CompetitionMetric,
        generatedAt: Date,
        rows: [LeaderboardRow],
        currentUserRank: Int?,
        gapToNextRank: Double?,
        headline: String
    ) {
        self.window = window
        self.metric = metric
        self.generatedAt = generatedAt
        self.rows = rows
        self.currentUserRank = currentUserRank
        self.gapToNextRank = gapToNextRank.map { max(0, $0) }
        self.headline = headline
    }
}
