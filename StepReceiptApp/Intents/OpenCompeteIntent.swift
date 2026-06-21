@preconcurrency import AppIntents
import Foundation

struct OpenCompeteIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Compete"
    static let description = IntentDescription("Opens the Compete tab in StepReceipt.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            StepReceiptAppIntentsSupport.repository?.openCompeteTab()
        }
        return .result()
    }
}
