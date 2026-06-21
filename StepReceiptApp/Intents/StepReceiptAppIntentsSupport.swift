import Foundation

enum StepReceiptIntentError: Error, CustomLocalizedStringResourceConvertible {
    case repositoryUnavailable
    case boardDisabled

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .repositoryUnavailable:
            "StepReceipt is not ready yet. Open the app and try again."
        case .boardDisabled:
            "Household compete board is not enabled."
        }
    }
}

@MainActor
enum StepReceiptAppIntentsSupport {
    static weak var repository: ActivityRepository?
}
