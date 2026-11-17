import SwiftUI
import WidgetKit

struct GTDiningInlineView: View {
    let entry: GTDiningEntry

    var body: some View {
        Label(text, systemImage: "fork.knife")
            .accessibilityLabel(text)
    }

    private var text: String {
        if entry.fetchFailed { return "Dining unavailable" }
        if let place = entry.places.first(where: \.isOpen) { return "\(place.name) is open" }
        return "Dining closed"
    }
}
