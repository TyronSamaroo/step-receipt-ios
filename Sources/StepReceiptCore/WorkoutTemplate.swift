import Foundation

public enum WorkoutTemplate: String, Codable, CaseIterable, Identifiable, Sendable {
    case pushDay
    case pullDay
    case legDay
    case stairSession
    case outdoorWalk
    case indoorWalk

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .pushDay: "Push Day"
        case .pullDay: "Pull Day"
        case .legDay: "Leg Day"
        case .stairSession: "Stair Session"
        case .outdoorWalk: "Outdoor Walk"
        case .indoorWalk: "Indoor Walk"
        }
    }

    public var shortDescription: String {
        switch self {
        case .pushDay: "Chest, shoulders, triceps"
        case .pullDay: "Back, biceps, rear delts"
        case .legDay: "Quads, hamstrings, glutes"
        case .stairSession: "Stairs, climber, incline work"
        case .outdoorWalk: "Outdoor steps and distance"
        case .indoorWalk: "Treadmill or indoor route"
        }
    }

    public var primaryActivityKind: ActivityKind {
        switch self {
        case .pushDay, .pullDay, .legDay:
            .strengthTraining
        case .stairSession:
            .stairClimbing
        case .outdoorWalk, .indoorWalk:
            .walking
        }
    }

    public func isSuggested(for workout: WorkoutActivity) -> Bool {
        switch self {
        case .pushDay, .pullDay, .legDay:
            workout.type == .strengthTraining
        case .stairSession:
            workout.type == .stairClimbing || workout.type == .elliptical
        case .outdoorWalk:
            workout.type == .walking && workout.environment != .indoor
        case .indoorWalk:
            workout.type == .walking && workout.environment != .outdoor
        }
    }

    public static func suggestions(for workout: WorkoutActivity) -> [WorkoutTemplate] {
        allCases.filter { $0.isSuggested(for: workout) }
    }

    public static func preferred(for workout: WorkoutActivity, tag: String? = nil) -> WorkoutTemplate? {
        if let tagTemplate = template(matching: tag) {
            return tagTemplate
        }

        return suggestions(for: workout).first
    }

    public static func template(matching tag: String?) -> WorkoutTemplate? {
        guard let normalizedTag = tag.map(normalizedName), !normalizedTag.isEmpty else {
            return nil
        }

        return allCases.first { template in
            normalizedName(template.displayName) == normalizedTag
        }
    }

    private static func normalizedName(_ value: String) -> String {
        value
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }
}
