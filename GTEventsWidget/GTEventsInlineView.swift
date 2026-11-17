import SwiftUI
import WidgetKit

struct GTEventsInlineView: View {
    let entry: GTEventsEntry

    var body: some View {
        Label(text, systemImage: "calendar")
            .containerBackground(for: .widget) { AccessoryWidgetBackground() }
    }

    private var text: String {
        if entry.isStale { return "Events \(entry.asOfText)" }
        if let event = entry.headline {
            return "\(event.title) at \(time(event))"
        }
        if let next = entry.nextDay {
            return "\(next.title) \(entry.dayLabel(for: next)) at \(time(next))"
        }
        return entry.fetchFailed ? "Events unavailable" : "No events today"
    }

    private func time(_ event: EventTileData) -> String {
        event.start.formatted(date: .omitted, time: .shortened)
    }
}

#Preview(as: .accessoryInline) {
    GTEventsWidget()
} timeline: {
    let event = EventTileData(eventID: "1", title: "ASO Pickleball", location: "Student Center",
                              start: .now.addingTimeInterval(3600), end: .now.addingTimeInterval(7200),
                              categories: [])
    GTEventsEntry(date: .now, fetchedAt: .now, upcoming: [event], nextDay: nil,
                  hadEventsToday: true, isStale: false, fetchFailed: false)
    GTEventsEntry(date: .now, fetchedAt: .now, upcoming: [], nextDay: nil,
                  hadEventsToday: false, isStale: false, fetchFailed: true)
}
