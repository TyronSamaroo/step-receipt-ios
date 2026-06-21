import Foundation

struct AppDiagnosticsSummary: Equatable {
    let appVersion: String
    let appBuild: String
    let appleHealthStatus: String
    let healthRefreshStatus: String
    let healthLastRefresh: String?
    let healthBackgroundUpdates: String
    let iCloudStatus: String
    let liveActivityStatus: String
    let competeBoardStatus: String
    let competeMemberCount: Int
    let competeSyncStatus: String

    var text: String {
        var lines = [
            "StrideSlip Diagnostics",
            "App: \(appVersion) (\(appBuild))",
            "Apple Health: \(appleHealthStatus)",
            "Health Refresh: \(healthRefreshStatus)",
            "Background Updates: \(healthBackgroundUpdates)",
            "iCloud: \(iCloudStatus)",
            "Household Board: \(competeBoardStatus)",
            "Household Members: \(competeMemberCount)",
            "Compete Sync: \(competeSyncStatus)",
            "Live Activity: \(liveActivityStatus)"
        ]

        if let healthLastRefresh {
            lines.insert("Last Health Refresh: \(healthLastRefresh)", at: 5)
        }

        return lines.joined(separator: "\n")
    }

    static func appVersion(bundle: Bundle = .main) -> String {
        bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    static func appBuild(bundle: Bundle = .main) -> String {
        bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    }
}
