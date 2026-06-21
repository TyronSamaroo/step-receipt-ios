import SwiftUI

@main
@MainActor
struct StepReceiptApp: App {
    @UIApplicationDelegateAdaptor(StepReceiptAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var repository: ActivityRepository

    private static let sharedRepository = makeRepository()

    init() {
        _repository = StateObject(wrappedValue: Self.sharedRepository)
        StepReceiptAppIntentsSupport.repository = Self.sharedRepository
        appDelegate.competitionNotificationHandler = {
            await Self.sharedRepository.handleCompetitionCloudKitNotification()
        }

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
                    guard url.scheme == "stepreceipt" else { return }
                    if url.host == "today" {
                        Task { await repository.refreshAfterAppBecameActive() }
                    } else if url.host == "compete" {
                        repository.openCompeteTab()
                    }
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

            await repository.refreshLiveActivityTick()
        }
    }

    private static func makeRepository() -> ActivityRepository {
        #if LOCAL_NO_CLOUDKIT
        ActivityRepository(
            cloudKit: DisabledCloudKitSummarySync(),
            competitionSync: DisabledSharedCompetitionSync(),
            competitionSubscription: DisabledCompetitionSubscriptionService(),
            watchSync: DisabledWatchAggregateSyncService()
        )
        #else
        ActivityRepository(
            weatherKit: LiveWeatherKitClient(),
            locationProvider: LiveLocationProvider(),
            competitionSubscription: LiveCloudKitCompetitionSubscriptionService()
        )
        #endif
    }
}
