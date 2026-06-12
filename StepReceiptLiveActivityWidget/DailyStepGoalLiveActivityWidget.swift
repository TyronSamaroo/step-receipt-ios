import ActivityKit
import SwiftUI
import WidgetKit

@main
struct StepReceiptLiveActivityWidgets: WidgetBundle {
    var body: some Widget {
        DailyStepGoalLiveActivityWidget()
    }
}

struct DailyStepGoalLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DailyStepGoalAttributes.self) { context in
            StepGoalLockScreenView(context: context)
                .activityBackgroundTint(.stepWidgetSurface)
                .activitySystemActionForegroundColor(.stepWidgetAccent)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    StepGoalIslandMetric(
                        title: "Steps",
                        value: context.state.steps.formatted()
                    )
                }

                DynamicIslandExpandedRegion(.trailing) {
                    StepGoalIslandMetric(
                        title: "Left",
                        value: context.state.remainingSteps.formatted()
                    )
                }

                DynamicIslandExpandedRegion(.bottom) {
                    StepGoalProgressBar(progress: context.state.progress)
                        .padding(.top, 2)
                }
            } compactLeading: {
                Image(systemName: "figure.walk")
                    .foregroundStyle(Color.stepWidgetAccent)
            } compactTrailing: {
                Text("\(Int((context.state.progress * 100).rounded()))%")
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: context.state.isGoalComplete ? "checkmark.circle.fill" : "figure.walk")
                    .foregroundStyle(Color.stepWidgetAccent)
            }
            .widgetURL(URL(string: "stepreceipt://today"))
        }
    }
}

private struct StepGoalLockScreenView: View {
    let context: ActivityViewContext<DailyStepGoalAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label("Daily Step Goal", systemImage: "figure.walk")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.stepWidgetInk)
                Spacer(minLength: 8)
                Text(context.state.isGoalComplete ? "Cleared" : "\(context.state.remainingSteps.formatted()) left")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(context.state.isGoalComplete ? Color.stepWidgetAccent : Color.stepWidgetMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(context.state.steps.formatted())
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.stepWidgetInk)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text("of \(context.state.stepGoal.formatted())")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.stepWidgetMuted)
                    .lineLimit(1)
            }

            StepGoalProgressBar(progress: context.state.progress)

            Text("Updated \(context.state.updatedAt, style: .time)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.stepWidgetMuted)
        }
        .padding(16)
    }
}

private struct StepGoalIslandMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.stepWidgetMuted)
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.stepWidgetInk)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }
}

private struct StepGoalProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.stepWidgetMuted.opacity(0.20))
                Capsule()
                    .fill(Color.stepWidgetAccent)
                    .frame(width: proxy.size.width * min(1, max(0, progress)))
            }
        }
        .frame(height: 8)
    }
}

private extension Color {
    static let stepWidgetSurface = Color(red: 0.96, green: 0.98, blue: 0.95)
    static let stepWidgetInk = Color(red: 0.07, green: 0.09, blue: 0.08)
    static let stepWidgetMuted = Color(red: 0.28, green: 0.34, blue: 0.31)
    static let stepWidgetAccent = Color(red: 0.08, green: 0.45, blue: 0.38)
}
