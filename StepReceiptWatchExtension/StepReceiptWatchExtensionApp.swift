import SwiftUI
import WatchConnectivity

@main
struct StepReceiptWatchExtensionApp: App {
    @StateObject private var sessionModel = WatchSessionModel()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(sessionModel)
        }
    }
}

@MainActor
final class WatchSessionModel: NSObject, ObservableObject {
    @Published private(set) var snapshot: WatchAggregateSnapshot = .empty

    private let session: WCSession?

    override init() {
        if WCSession.isSupported() {
            session = WCSession.default
        } else {
            session = nil
        }
        super.init()
        session?.delegate = self
        session?.activate()
    }
}

extension WatchSessionModel: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        applySnapshot(from: session.receivedApplicationContext)
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        applySnapshot(from: applicationContext)
    }

    nonisolated private func applySnapshot(from context: [String: Any]) {
        guard
            let encoded = context[WatchAggregateSnapshot.contextKey] as? String,
            let snapshot = WatchAggregateSnapshot.decode(from: encoded)
        else {
            return
        }

        Task { @MainActor in
            self.snapshot = snapshot
        }
    }
}

struct WatchContentView: View {
    @EnvironmentObject private var sessionModel: WatchSessionModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Today")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                WatchStepGoalRing(snapshot: sessionModel.snapshot)

                Text("\(sessionModel.snapshot.steps.formatted()) steps")
                    .font(.title3.bold())

                Text("\(sessionModel.snapshot.progressPercent)% of \(sessionModel.snapshot.stepGoal.formatted()) goal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if sessionModel.snapshot.householdBoardActive {
                    Divider()
                    Text("Compete")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let rank = sessionModel.snapshot.competeRank {
                        Text("Rank #\(rank)")
                            .font(.headline)
                    }

                    if let headline = sessionModel.snapshot.competeHeadline, !headline.isEmpty {
                        Text(headline)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
    }
}

private struct WatchStepGoalRing: View {
    let snapshot: WatchAggregateSnapshot

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.25), lineWidth: 10)
            Circle()
                .trim(from: 0, to: snapshot.progress)
                .stroke(
                    Color(red: 0.075, green: 0.445, blue: 0.375),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text("\(snapshot.progressPercent)%")
                .font(.caption.bold())
        }
        .frame(width: 92, height: 92)
    }
}
