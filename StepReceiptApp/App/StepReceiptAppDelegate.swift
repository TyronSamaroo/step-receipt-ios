import CloudKit
import UIKit

final class StepReceiptAppDelegate: NSObject, UIApplicationDelegate {
    var competitionNotificationHandler: (@Sendable () async -> Void)?
    var competitionShareAcceptanceHandler: (@Sendable (CKShare.Metadata) async -> Void)?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        true
    }

    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith metadata: CKShare.Metadata,
        completionHandler: @escaping (URL?) -> Void
    ) {
        guard let handler = competitionShareAcceptanceHandler else {
            completionHandler(nil)
            return
        }

        Task { @MainActor in
            await handler(metadata)
            completionHandler(nil)
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {}

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {}

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard CKNotification(fromRemoteNotificationDictionary: userInfo) != nil else {
            completionHandler(.noData)
            return
        }

        guard let handler = competitionNotificationHandler else {
            completionHandler(.noData)
            return
        }

        Task {
            await handler()
            completionHandler(.newData)
        }
    }
}
