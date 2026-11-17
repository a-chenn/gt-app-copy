import SwiftUI
import WidgetKit

struct GTDiningRectangularView: View {
    let entry: GTDiningEntry

    var body: some View {
        AccessoryThreeLines(icon: "fork.knife",
                            title: content.title,
                            subtitle: content.subtitle,
                            detail: content.detail)
            .containerBackground(for: .widget) { AccessoryWidgetBackground() }
    }

    /// Mirrors GTDiningSmallView's decisions: failed, then open (openCount > 0), then closed.
    private var content: (title: String, subtitle: String, detail: String?) {
        if entry.fetchFailed {
            return ("Can't reach GT", "Dining unavailable", WidgetText.asOf(entry.fetchedAt))
        }
        if entry.openCount > 0 {
            let place = entry.places.first(where: \.isOpen)
            return (place?.name ?? "Dining",
                    entry.soonestClosingText ?? place?.statusText ?? "Open now",
                    WidgetText.placesOpen(entry.openCount))
        }
        return ("Nothing open", entry.nextOpenText ?? "Closed", nil)
    }
}

#Preview(as: .accessoryRectangular) {
    GTDiningWidget()
} timeline: {
    let place = DiningPlaceData(name: "North Ave Dining Hall", statusText: "Open until 2:00AM",
                                isOpen: true, closesAtMinutes: 120, opensAtMinutes: nil)
    GTDiningEntry(date: .now, fetchedAt: .now, openCount: 3, places: [place],
                  soonestClosingText: place.statusText, nextOpenText: nil, fetchFailed: false)
    GTDiningEntry(date: .now, fetchedAt: .now, openCount: 0, places: [],
                  soonestClosingText: nil, nextOpenText: "Opens 7:00AM", fetchFailed: false)
    GTDiningEntry(date: .now, fetchedAt: .now, openCount: 0, places: [],
                  soonestClosingText: nil, nextOpenText: nil, fetchFailed: true)
}
