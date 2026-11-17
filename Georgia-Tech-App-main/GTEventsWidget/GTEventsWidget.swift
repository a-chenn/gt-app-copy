//
//  GTEventsWidget.swift
//  GTCapacityWidget
//

import SwiftUI
import WidgetKit

struct GTEventsWidget: Widget {
    let kind = "GTEventsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GTEventsWidgetProvider()) { entry in
            GTEventsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Today on Campus")
        .description("What's happening at Georgia Tech today.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

struct GTEventsWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GTEventsEntry

    var body: some View {
        switch family {
        case .systemMedium:
            // Rows link to their own event; a tap anywhere else opens the Events tab.
            GTEventsMediumView(entry: entry)
                .widgetURL(GTEventsWidgetLink.url(for: nil))
        case .accessoryRectangular:
            GTEventsRectangularView(entry: entry)
                .widgetURL(GTEventsWidgetLink.url(for: entry.headline ?? entry.nextDay))
        case .accessoryInline:
            GTEventsInlineView(entry: entry)
                .widgetURL(GTEventsWidgetLink.url(for: entry.headline ?? entry.nextDay))
        default:
            GTEventsSmallView(entry: entry)
                .widgetURL(GTEventsWidgetLink.url(for: entry.headline ?? entry.nextDay))
        }
    }
}

/// Deep links into the app's existing gtapp:// handler (AppShellView.onOpenURL),
/// which hands `gtapp://event?id=<eventID>` to the same route a reminder
/// notification uses. No id → the Events tab.
enum GTEventsWidgetLink {
    static func url(for event: EventTileData?) -> URL? {
        var components = URLComponents()
        components.scheme = "gtapp"
        components.host = "event"
        if let event {
            components.queryItems = [URLQueryItem(name: "id", value: event.eventID)]
        }
        return components.url
    }
}
