import SwiftUI
import WeatherKit

struct WeatherAttributionView: View {
    @State private var attributionURL: URL?

    var body: some View {
        Group {
            if let url = attributionURL {
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Image(systemName: "apple.logo")
                            .font(.caption2)
                        Text("Weather")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(Color.stepMuted)
                }
                .accessibilityLabel("Apple Weather attribution")
            }
        }
        .task {
            do {
                let attribution = try await WeatherService.shared.attribution
                attributionURL = attribution.legalPageURL
            } catch {
                attributionURL = nil
            }
        }
    }
}
