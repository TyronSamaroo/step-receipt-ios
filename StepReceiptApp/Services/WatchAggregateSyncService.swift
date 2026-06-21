import Foundation
import WatchConnectivity

protocol WatchAggregatePublishing: Sendable {
    func publish(_ snapshot: WatchAggregateSnapshot)
}

final class WatchAggregateSyncService: NSObject, WatchAggregatePublishing, @unchecked Sendable {
    static let shared = WatchAggregateSyncService()

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

    func publish(_ snapshot: WatchAggregateSnapshot) {
        guard
            let session,
            session.activationState == .activated,
            let encoded = snapshot.encodedContextValue()
        else {
            return
        }

        do {
            try session.updateApplicationContext([WatchAggregateSnapshot.contextKey: encoded])
        } catch {
            // Watch may be unreachable; latest snapshot stays on phone until next update.
        }
    }
}

extension WatchAggregateSyncService: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}

struct DisabledWatchAggregateSyncService: WatchAggregatePublishing, Sendable {
    func publish(_ snapshot: WatchAggregateSnapshot) {}
}
