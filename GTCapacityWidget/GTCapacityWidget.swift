//
//  GTCapacityWidget.swift
//  GTCapacityWidget
//

import SwiftUI
import WidgetKit

struct GTCapacityWidget: Widget {
    let kind = "GTCapacityWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GTCapacityWidgetProvider()) { entry in
            GTCapacityWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Right Now")
        .description("Live building occupancy at Georgia Tech.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct GTCapacityWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GTCapacityEntry

    var body: some View {
        switch family {
        case .systemMedium:
            GTCapacityMediumView(entry: entry)
        default:
            GTCapacitySmallView(entry: entry)
                .widgetURL(
                    entry.crc.flatMap { URL(string: "gtapp://capacities?id=\($0.buildingID)") }
                    ?? URL(string: "gtapp://capacities")
                )
        }
    }
}

// WidgetBundle — keeps one entry point even if future widgets are added.
@main
struct GTCapacityWidgetBundle: WidgetBundle {
    var body: some Widget {
        GTCapacityWidget()
        GTCapacityPhotoWidget()
        GTDiningWidget()
        GTEventsWidget()
        GTBusWidget()
        GTFunWidget()
    }
}
