import SwiftUI
import WidgetKit

struct GTBusInlineView: View {
    let entry: GTBusEntry

    var body: some View {
        Label(text, systemImage: "bus")
            .accessibilityLabel(text)
    }

    /// Narrowest copy first: "Red · 7 min".
    private var text: String {
        switch entry.state {
        case .arrivals(let rows):
            guard let next = rows.first else { return "No buses soon" }
            return "\(next.routeName) · \(WidgetText.minutes(next.secondsToStop))"
        case .noService: return "No bus service"
        case .noArrivals: return "No buses soon"
        case .checking: return "Checking bus…"
        case .notConfigured: return "Choose a stop"
        case .stopGone: return "Stop not found"
        case .fetchFailed: return "Bus unavailable"
        }
    }
}
