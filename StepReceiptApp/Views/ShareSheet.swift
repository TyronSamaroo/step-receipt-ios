import SwiftUI
import UIKit

struct ShareImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

enum ShareImageRenderer {
    @MainActor
    static func render<Content: View>(@ViewBuilder content: () -> Content) -> ShareImage? {
        let renderer = ImageRenderer(content: content().environment(\.colorScheme, .light))
        renderer.scale = UIScreen.main.scale
        guard let image = renderer.uiImage else { return nil }
        return ShareImage(image: image)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
