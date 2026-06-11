import SwiftUI

@main
@MainActor
struct StepReceiptApp: App {
    @StateObject private var repository = Self.makeRepository()

    init() {
        #if canImport(UIKit)
        StepReceiptChrome.configure()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(repository)
                .task {
                    await repository.bootstrap()
            }
        }
    }

    private static func makeRepository() -> ActivityRepository {
        #if LOCAL_NO_CLOUDKIT
        ActivityRepository(
            cloudKit: DisabledCloudKitSummarySync(),
            competitionSync: DisabledSharedCompetitionSync()
        )
        #else
        ActivityRepository()
        #endif
    }
}
