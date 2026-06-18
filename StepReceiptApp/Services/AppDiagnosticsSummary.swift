import Foundation

struct AppDiagnosticsSummary: Equatable {
    let appVersion: String
    let appBuild: String
    let appleHealthStatus: String
    let healthRefreshStatus: String
    let healthLastRefresh: String?
    let iCloudStatus: String
    let liveActivityStatus: String

    var text: String {
        var lines = [
            "StrideSlip Diagnostics",
            "App: \(appVersion) (\(appBuild))",
            "Apple Health: \(appleHealthStatus)",
            "Health Refresh: \(healthRefreshStatus)",
            "iCloud: \(iCloudStatus)",
            "Live Activity: \(liveActivityStatus)"
        ]

        if let healthLastRefresh {
            lines.insert("Last Health Refresh: \(healthLastRefresh)", at: 4)
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
