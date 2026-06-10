import SwiftUI

struct WorkoutDetailView: View {
    @EnvironmentObject private var repository: ActivityRepository
    let workout: WorkoutActivity
    @State private var shareImage: ShareImage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                WorkoutShareCard(workout: workout, distanceUnit: repository.preferences.distanceUnit)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Details")
                        .font(.headline)
                    detailRow("Duration", ActivityFormatting.formattedMinutes(workout.durationMinutes), StepReceiptSymbol.workout)
                    if let distance = workout.distanceMeters {
                        detailRow("Distance", ActivityFormatting.formattedDistance(from: distance, unit: repository.preferences.distanceUnit), StepReceiptSymbol.distance)
                    }
                    if let burn = workout.activeEnergyKilocalories {
                        detailRow("Active burn", ActivityFormatting.formattedCalories(burn), StepReceiptSymbol.activeEnergy)
                    }
                    if let steps = workout.steps {
                        detailRow("Steps", steps.formatted(), StepReceiptSymbol.stepPrints)
                    }
                    detailRow("Source", workout.sourceName, StepReceiptSymbol.healthCard)
                }
                .metricCard()
            }
            .padding(16)
        }
        .safeAreaPadding(.bottom, 84)
        .background(Color.stepBackground)
        .navigationTitle(workout.type.displayName)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    shareImage = ShareImageRenderer.render {
                        WorkoutShareCard(workout: workout, distanceUnit: repository.preferences.distanceUnit)
                            .frame(width: 390)
                            .padding(18)
                            .background(Color.stepBackground)
                    }
                } label: {
                    Image(systemName: StepReceiptSymbol.share)
                }
                .accessibilityLabel("Share workout")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareImage) { shareImage in
            ShareSheet(items: [shareImage.image])
        }
    }

    private func detailRow(_ title: String, _ value: String, _ icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.stepAccent)
                .frame(width: 24)
            Text(title)
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

struct WorkoutShareCard: View {
    let workout: WorkoutActivity
    let distanceUnit: DistanceUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.type.displayName.uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.stepAccent)
                    Text("Workout Receipt")
                        .font(.title.weight(.bold))
                        .foregroundStyle(Color.stepInk)
                }
                Spacer()
                Image(systemName: StepReceiptSymbol.workoutIcon(for: workout.type))
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Color.stepAccent)
                    .frame(width: 52, height: 52)
                    .background(Color.stepAccent.opacity(0.12))
                    .clipShape(Circle())
            }

            HStack(spacing: 12) {
                receiptMetric("Duration", ActivityFormatting.formattedMinutes(workout.durationMinutes))
                if let distance = workout.distanceMeters {
                    receiptMetric("Distance", ActivityFormatting.formattedDistance(from: distance, unit: distanceUnit))
                }
                if let burn = workout.activeEnergyKilocalories {
                    receiptMetric("Burn", ActivityFormatting.formattedCalories(burn))
                }
            }

            Text(workout.startDate, format: .dateTime.weekday(.wide).month(.wide).day().hour().minute())
                .font(.footnote)
                .foregroundStyle(Color.stepMuted)
                .lineLimit(2)
        }
        .padding(18)
        .background(Color.stepSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func receiptMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundStyle(Color.stepInk)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.stepMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
