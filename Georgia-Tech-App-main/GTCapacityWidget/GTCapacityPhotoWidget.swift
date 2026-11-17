//
//  GTCapacityPhotoWidget.swift
//  GTCapacityWidget
//

import SwiftUI
import WidgetKit

struct GTCapacityPhotoWidget: Widget {
    let kind = "GTCapacityPhotoWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: BuildingCapacityIntent.self,
            provider: GTCapacityPhotoWidgetProvider()
        ) { entry in
            GTCapacityPhotoEntryView(entry: entry)
        }
        .configurationDisplayName("Building Capacity")
        .description("Live occupancy with photo background.")
        .supportedFamilies([.systemMedium, .accessoryRectangular])
    }
}
