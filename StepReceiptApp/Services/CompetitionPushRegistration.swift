import UIKit

enum CompetitionPushRegistration {
    @MainActor
    static func registerIfNeeded(boardEnabled: Bool) {
        guard boardEnabled else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }
}
