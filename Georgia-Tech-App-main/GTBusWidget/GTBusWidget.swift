//
//  GTBusWidget.swift
//  GTBusWidget
//

import SwiftUI
import WidgetKit

struct GTBusWidget: Widget {
    let kind = "GTBusWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: BusStopIntent.self,
            provider: GTBusWidgetProvider()
        ) { entry in
            GTBusWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Next Bus")
        .description("Live bus arrivals at your stop.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct GTBusWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GTBusEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                GTBusMediumView(entry: entry)
            case .accessoryRectangular:
                GTBusRectangularView(entry: entry)
            case .accessoryInline:
                GTBusInlineView(entry: entry)
            default:
                GTBusSmallView(entry: entry)
            }
        }
        .widgetURL(URL(string: "gtapp://busstop?id=\(entry.routeStopID)"))
    }
}
