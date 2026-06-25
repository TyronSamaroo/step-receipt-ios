import SwiftUI

struct CoachInsightsSheet: View {
    @EnvironmentObject private var repository: ActivityRepository
    @Environment(\.dismiss) private var dismiss

    let insights: [TodayCoachInsight]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(insights) { insight in
                        if insight.kind == .household {
                            Button {
                                repository.openCompeteTab()
                                dismiss()
                            } label: {
                                coachDetailRow(insight, showsCompeteLink: true)
                            }
                            .buttonStyle(.plain)
                        } else {
                            coachDetailRow(insight, showsCompeteLink: false)
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.stepBackground)
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .accessibilityIdentifier("today-coach-insights-sheet")
        }
    }

    private func coachDetailRow(_ insight: TodayCoachInsight, showsCompeteLink: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: insight.systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(coachAccent(for: insight.kind))
                .frame(width: 32, height: 32)
                .background(coachAccent(for: insight.kind).opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(insight.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.stepInk)
                Text(insight.detail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.stepMuted)
                    .fixedSize(horizontal: false, vertical: true)
                if showsCompeteLink {
                    Text("Open Compete")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.stepAccent)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.stepSurface.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func coachAccent(for kind: TodayCoachInsightKind) -> Color {
        switch kind {
        case .goal, .projection:
            Color.stepAccent
        case .pace, .peakHour:
            Color.stepDistance
        case .workout:
            Color.stepEnergy
        case .household:
            Color.stepMuted
        case .streak:
            Color.stepWarning
        case .general:
            Color.stepAccent
        }
    }
}
