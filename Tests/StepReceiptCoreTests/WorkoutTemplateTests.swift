import Foundation
import Testing
#if canImport(StepReceiptCore)
@testable import StepReceiptCore
#endif

struct WorkoutTemplateTests {
    @Test
    func testStrengthWorkoutSuggestsTrainingSplitTemplates() {
        let workout = WorkoutActivity(
            sourceIdentifier: "strength",
            type: .strengthTraining,
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: 3_600)
        )

        #expect(WorkoutTemplate.suggestions(for: workout) == [.pushDay, .pullDay, .legDay])
        #expect(WorkoutTemplate.preferred(for: workout) == .pushDay)
    }

    @Test
    func testCardioWorkoutSuggestionsRespectTypeAndEnvironment() {
        let start = Date(timeIntervalSince1970: 0)
        let stairWorkout = WorkoutActivity(
            sourceIdentifier: "stairs",
            type: .stairClimbing,
            startDate: start,
            endDate: start.addingTimeInterval(30 * 60)
        )
        let outdoorWalk = WorkoutActivity(
            sourceIdentifier: "outdoor-walk",
            type: .walking,
            startDate: start,
            endDate: start.addingTimeInterval(45 * 60),
            environment: .outdoor
        )
        let indoorWalk = WorkoutActivity(
            sourceIdentifier: "indoor-walk",
            type: .walking,
            startDate: start,
            endDate: start.addingTimeInterval(45 * 60),
            environment: .indoor
        )

        #expect(WorkoutTemplate.suggestions(for: stairWorkout) == [.stairSession])
        #expect(WorkoutTemplate.suggestions(for: outdoorWalk) == [.outdoorWalk])
        #expect(WorkoutTemplate.suggestions(for: indoorWalk) == [.indoorWalk])
    }

    @Test
    func testTemplateMatchingUsesLocalTagTextOnly() {
        #expect(WorkoutTemplate.template(matching: " Push Day ") == .pushDay)
        #expect(WorkoutTemplate.template(matching: "stair-session") == .stairSession)
        #expect(WorkoutTemplate.template(matching: "Custom Arm Day") == nil)
    }
}
