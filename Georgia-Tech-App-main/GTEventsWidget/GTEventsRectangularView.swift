import SwiftUI
import WidgetKit

struct GTEventsRectangularView: View {
    let entry: GTEventsEntry

    var body: some View {
        AccessoryThreeLines(showsBar: true,
                            title: content.title,
                            subtitle: content.subtitle,
                            detail: content.detail)
            .containerBackground(for: .widget) { AccessoryWidgetBackground() }
    }

    /// when / what / where (or "as of" when the data is old).
    private var content: (title: String, subtitle: String, detail: String?) {
        if let event = entry.headline {
            let time = event.start.formatted(date: .omitted, time: .shortened)
            return ("Today at \(time)", event.title, detail(for: event))
        }
        if let next = entry.nextDay {
            let time = next.start.formatted(date: .omitted, time: .shortened)
            return ("\(entry.dayLabel(for: next)) at \(time)", next.title, detail(for: next))
        }
        if entry.fetchFailed {
            return ("Can't reach GT", "Events unavailable", nil)
        }
        return ("Events", entry.hadEventsToday ? "Nothing else today" : "Nothing scheduled today", nil)
    }

    /// Line 3: "as of" when stale, otherwise the location (with a game-day tag if it applies).
    private func detail(for event: EventTileData) -> String? {
        if entry.isStale { return entry.asOfText }
        let gameDay = entry.isGameDay(event) ? "Game day" : nil
        return [gameDay, event.location].compactMap { $0 }.joined(separator: " · ").nilIfEmpty
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

#Preview(as: .accessoryRectangular) {
    GTEventsWidget()
} timeline: {
    let event = EventTileData(eventID: "1", title: "ASO Pickleball", location: "Student Center",
                              start: .now.addingTimeInterval(3600), end: .now.addingTimeInterval(7200),
                              categories: [])
    GTEventsEntry(date: .now, fetchedAt: .now, upcoming: [event], nextDay: nil,
                  hadEventsToday: true, isStale: false, fetchFailed: false)
    GTEventsEntry(date: .now, fetchedAt: .now, upcoming: [event], nextDay: nil,
                  hadEventsToday: true, isStale: true, fetchFailed: false)
    GTEventsEntry(date: .now, fetchedAt: .now, upcoming: [], nextDay: nil,
                  hadEventsToday: true, isStale: false, fetchFailed: false)
    GTEventsEntry(date: .now, fetchedAt: .now, upcoming: [], nextDay: nil,
                  hadEventsToday: false, isStale: false, fetchFailed: true)
}
