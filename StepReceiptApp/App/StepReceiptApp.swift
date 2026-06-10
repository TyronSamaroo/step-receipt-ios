import SwiftUI

@main
@MainActor
struct StepReceiptApp: App {
    @StateObject private var repository = ActivityRepository()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(repository)
                .task {
                    await repository.bootstrap()
                }
        }
    }
}
