import AppIntents
import Foundation
import SwiftUI

struct TodayStepsEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Today's Steps")
    static var defaultQuery = TodayStepsEntityQuery()

    var id: String { "today-steps" }
    var steps: Int
    var stepGoal: Int
    var progressPercent: Int

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(steps.formatted()) steps",
            subtitle: "\(progressPercent)% of \(stepGoal.formatted()) goal"
        )
    }
}

struct TodayStepsEntityQuery: EntityQuery {
    func entities(for identifiers: [TodayStepsEntity.ID]) async throws -> [TodayStepsEntity] {
        guard let entity = try await suggestedEntities().first else { return [] }
        return identifiers.contains(entity.id) ? [entity] : []
    }

    func suggestedEntities() async throws -> [TodayStepsEntity] {
        await MainActor.run {
            guard
                let repository = StepReceiptAppIntentsSupport.repository,
                let summary = repository.todaySummary
            else {
                return []
            }

            let goal = max(1, repository.goals.stepsPerDay)
            let progress = min(100, Int((Double(summary.steps) / Double(goal) * 100).rounded()))
            return [
                TodayStepsEntity(
                    steps: summary.steps,
                    stepGoal: goal,
                    progressPercent: progress
                )
            ]
        }
    }
}

struct GetTodayStepsIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Today's Steps"
    static var description = IntentDescription("Returns today's step count and goal progress.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<TodayStepsEntity> & ProvidesDialog & ShowsSnippetView {
        let entity = await MainActor.run { () -> TodayStepsEntity in
            let repository = StepReceiptAppIntentsSupport.repository
            let steps = repository?.todaySummary?.steps ?? 0
            let goal = max(1, repository?.goals.stepsPerDay ?? 10_000)
            let progress = min(100, Int((Double(steps) / Double(goal) * 100).rounded()))
            return TodayStepsEntity(steps: steps, stepGoal: goal, progressPercent: progress)
        }

        let dialog = "\(entity.steps.formatted()) steps today — \(entity.progressPercent)% of your \(entity.stepGoal.formatted()) step goal."

        return .result(
            value: entity,
            dialog: IntentDialog(stringLiteral: dialog),
            view: TodayStepsSnippetView(entity: entity)
        )
    }
}

private struct TodayStepsSnippetView: View {
    let entity: TodayStepsEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(entity.steps.formatted()) steps")
                .font(.title2.bold())
            Text("\(entity.progressPercent)% of \(entity.stepGoal.formatted()) goal")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
