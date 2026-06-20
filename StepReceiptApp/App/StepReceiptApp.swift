import SwiftUI

@main
@MainActor
struct StepReceiptApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var repository: ActivityRepository

    private static let sharedRepository = makeRepository()

    init() {
        _repository = StateObject(wrappedValue: Self.sharedRepository)

        #if canImport(UIKit)
        StepReceiptChrome.configure()
        #endif

        Task {
            await Self.sharedRepository.configureHealthObserversOnLaunch()
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(repository)
                .task {
                    await repository.bootstrap()
                }
                .task(id: scenePhase) {
                    await runForegroundRefreshLoop(for: scenePhase)
                }
                .onOpenURL { url in
                    guard url.scheme == "stepreceipt", url.host == "today" else { return }
                    Task { await repository.refreshAfterAppBecameActive() }
                }
        }
    }

    private func runForegroundRefreshLoop(for phase: ScenePhase) async {
        guard phase == .active else { return }
        await repository.refreshAfterAppBecameActive()

        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(60))
            } catch {
                return
            }

            await repository.refreshAfterAppBecameActive()
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
