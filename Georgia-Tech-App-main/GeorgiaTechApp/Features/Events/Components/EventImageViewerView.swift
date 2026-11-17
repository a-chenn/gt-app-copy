import SwiftUI

/// Displays the full event artwork without cropping it to the carousel's landscape frame.
struct EventImageViewerView: View {
    let imageName: String
    let title: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .accessibilityLabel("Full image for \(title)")
            }
            .padding(16)
            .gtScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .accessibilityLabel("Close event image")
                }
            }
            .tint(Color.gtPrimaryText)
        }
    }
}
