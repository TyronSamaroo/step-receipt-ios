import Foundation

public struct WatchAggregateSnapshot: Codable, Equatable, Sendable {
    public static let contextKey = "stepReceipt.watchSnapshot.v1"

    public let steps: Int
    public let stepGoal: Int
    public let updatedAt: Date
    public let competeRank: Int?
    public let competeHeadline: String?
    public let householdBoardActive: Bool

    public init(
        steps: Int,
        stepGoal: Int,
        updatedAt: Date = Date(),
        competeRank: Int? = nil,
        competeHeadline: String? = nil,
        householdBoardActive: Bool = false
    ) {
        self.steps = max(0, steps)
        self.stepGoal = max(1, stepGoal)
        self.updatedAt = updatedAt
        self.competeRank = competeRank
        self.competeHeadline = competeHeadline
        self.householdBoardActive = householdBoardActive
    }

    public static let empty = WatchAggregateSnapshot(steps: 0, stepGoal: 10_000)

    public var progress: Double {
        min(1, Double(steps) / Double(stepGoal))
    }

    public var progressPercent: Int {
        Int((progress * 100).rounded())
    }

    public func encodedContextValue() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func decode(from contextValue: String) -> WatchAggregateSnapshot? {
        guard let data = contextValue.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(WatchAggregateSnapshot.self, from: data)
    }

    public static func decode(from context: [String: Any]) -> WatchAggregateSnapshot? {
        guard let value = context[contextKey] as? String else { return nil }
        return decode(from: value)
    }
}
