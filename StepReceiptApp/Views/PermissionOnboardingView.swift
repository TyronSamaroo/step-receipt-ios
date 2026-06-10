import SwiftUI

struct PermissionOnboardingView: View {
    @EnvironmentObject private var repository: ActivityRepository

    var body: some View {
        ZStack {
            Color.stepBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Image(systemName: StepReceiptSymbol.steps)
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(Color.stepAccent)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("StepReceipt")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.stepInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Text("Daily movement, workout receipts, and simple goal insight from Apple Health.")
                            .font(.title3)
                            .foregroundStyle(Color.stepMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        permissionRow(icon: StepReceiptSymbol.stepPrints, title: "Steps and distance", detail: "Builds your hourly timetable.")
                        permissionRow(icon: StepReceiptSymbol.activeEnergy, title: "Active calories", detail: "Shows burn trends without writing data.")
                        permissionRow(icon: StepReceiptSymbol.workoutIcon(for: .running), title: "Workouts", detail: "Creates shareable activity receipts.")
                    }

                    Button {
                        Task {
                            await repository.requestHealthAccess()
                        }
                    } label: {
                        Label("Connect Apple Health", systemImage: StepReceiptSymbol.healthCardFill)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.stepAccent)

                    Button {
                        repository.previewWithSampleData()
                    } label: {
                        Label("Preview Sample Data", systemImage: "sparkles")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .tint(.stepAccent)

                    Text("Raw HealthKit samples stay on this iPhone. CloudKit sync is limited to private daily summaries.")
                        .font(.footnote)
                        .foregroundStyle(Color.stepMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
        }
    }

    private func permissionRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 26)
                .foregroundStyle(Color.stepAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.stepInk)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Color.stepMuted)
            }
        }
    }
}
