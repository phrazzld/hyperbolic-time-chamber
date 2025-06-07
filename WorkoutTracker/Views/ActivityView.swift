import SwiftUI

// UIKit-only share-sheet wrapper
#if canImport(UIKit)
import UIKit

/// Wrapper for UIActivityViewController to support sharing files
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif