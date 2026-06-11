import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var repository: ActivityRepository
    @State private var shareImage: ShareImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let receipt = repository.receipt {
                        InsightReceiptCard(receipt: receipt, distanceUnit: repository.preferences.distanceUnit)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            MetricTile(title: "Daily Avg", value: "\(receipt.dailyAverageSteps.formatted())", icon: "calendar")
                            MetricTile(title: "Best Day", value: receipt.bestDay?.steps.formatted() ?? "0", icon: "star")
                            MetricTile(title: "Best Month", value: receipt.bestMonth?.steps.formatted() ?? "0", icon: "chart.bar")
                            MetricTile(title: "Streak", value: "\(receipt.currentStepGoalStreakDays)d", icon: StepReceiptSymbol.activeEnergy)
                        }

                        if let projected = receipt.projectedStepsToday {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Today Projection")
                                    .font(.headline)
                                Text("\(projected.formatted()) steps if the current pace holds.")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(Color.stepInk)
                            }
                            .metricCard()
                        }
                    } else {
                        ProgressView("Building receipt")
                            .frame(maxWidth: .infinity, minHeight: 260)
                    }
                }
                .padding(16)
            }
            .safeAreaPadding(.bottom, 84)
            .background(Color.stepBackground)
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if let receipt = repository.receipt {
                            shareImage = ShareImageRenderer.render {
                                InsightReceiptCard(receipt: receipt, distanceUnit: repository.preferences.distanceUnit)
                                    .frame(width: 390)
                                    .padding(18)
                                    .background(Color.stepBackground)
                            }
                        }
                    } label: {
                        Image(systemName: StepReceiptSymbol.share)
                    }
                    .accessibilityLabel("Share receipt")
                    .disabled(repository.receipt == nil)
                }
            }
        }
        .sheet(item: $shareImage) { shareImage in
            ShareSheet(items: [shareImage.image])
        }
    }
}

struct InsightReceiptCard: View {
    let receipt: InsightReceipt
    let distanceUnit: DistanceUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("STEP RECEIPT")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.stepAccent)
                    Text("\(receipt.totalSteps.formatted()) steps")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.stepInk)
                        .minimumScaleFactor(0.74)
                }
                Spacer()
                Image(systemName: StepReceiptSymbol.receipt)
                    .font(.system(size: 38))
                    .foregroundStyle(Color.stepAccent)
            }

            Text(receipt.onTrackMessage)
                .font(.headline)
                .foregroundStyle(Color.stepInk)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(spacing: 10) {
                receiptLine("Distance", ActivityFormatting.formattedDistance(from: receipt.totalDistanceMeters, unit: distanceUnit))
                receiptLine("Active burn", ActivityFormatting.formattedCalories(receipt.totalActiveEnergyKilocalories))
                receiptLine("Flights", receipt.totalFlightsClimbed.formatted())
                receiptLine("Workout time", ActivityFormatting.formattedMinutes(receipt.totalWorkoutMinutes))
                receiptLine("Goal days", "\(Int((receipt.stepGoalCompletionRate * 100).rounded()))%")
            }

            Text("\(receipt.periodStart, format: .dateTime.month().day()) - \(receipt.periodEnd, format: .dateTime.month().day())")
                .font(.footnote)
                .foregroundStyle(Color.stepMuted)
        }
        .padding(18)
        .background(Color.stepSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func receiptLine(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(Color.stepMuted)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(Color.stepInk)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .font(.subheadline)
    }
}
