//
//  GTDiningWidget.swift
//  GTCapacityWidget
//

import SwiftUI
import WidgetKit

struct GTDiningWidget: Widget {
    let kind = "GTDiningWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GTDiningWidgetProvider()) { entry in
            GTDiningWidgetEntryView(entry: entry)
                .widgetURL(URL(string: "gtapp://dining"))
        }
        .configurationDisplayName("Dining")
        .description("See what's open for food right now at Georgia Tech.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct GTDiningWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GTDiningEntry

    var body: some View {
        switch family {
        case .systemMedium:
            GTDiningMediumView(entry: entry)
        case .accessoryRectangular:
            GTDiningRectangularView(entry: entry)
        case .accessoryInline:
            GTDiningInlineView(entry: entry)
        default:
            GTDiningSmallView(entry: entry)
        }
    }
}
