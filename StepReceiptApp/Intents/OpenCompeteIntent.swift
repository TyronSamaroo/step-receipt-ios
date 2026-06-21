import AppIntents
import Foundation

struct OpenCompeteIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Compete"
    static var description = IntentDescription("Opens the Compete tab in StepReceipt.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            StepReceiptAppIntentsSupport.repository?.openCompeteTab()
        }
        return .result()
    }
}
