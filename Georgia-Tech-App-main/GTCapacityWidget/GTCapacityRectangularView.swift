import SwiftUI
import WidgetKit

struct GTCapacityRectangularView: View {
    let entry: GTCapacityPhotoEntry

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .containerBackground(for: .widget) { AccessoryWidgetBackground() }
    }

    @ViewBuilder
    private var content: some View {
        switch entry.state {
        case .loaded(let building) where building.isOpen:
            let level = CapacityLevel(percent: building.percentage * 100)
            VStack(alignment: .leading, spacing: 2) {
                Text(building.name)
                    .font(.headline)
                    .widgetAccentable()
                    .lineLimit(1)
                Text("\(WidgetText.percent(building.percentage)) · \(level.statusText)")
                    .font(.caption)
                    .lineLimit(1)
                Gauge(value: min(max(building.percentage, 0), 1)) { EmptyView() }
                    .gaugeStyle(.accessoryLinearCapacity)
            }
        case .loaded(let building):
            lines(building.name, "Closed")
        case .notConfigured:
            lines("Building Capacity", "Edit to choose a building")
        case .buildingNotFound:
            lines("Building Capacity", "Building not found")
        case .fetchFailed:
            lines("Building Capacity", "Can't reach GT · \(WidgetText.asOf(entry.fetchedAt))")
        }
    }

    private func lines(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline).lineLimit(1)
            Text(detail).font(.caption).lineLimit(2)
        }
    }

    private var accessibilityLabel: String {
        switch entry.state {
        case .loaded(let building) where building.isOpen:
            let level = CapacityLevel(percent: building.percentage * 100)
            return "\(building.name), \(level.statusText.lowercased()), "
                 + "\(Int(building.percentage * 100)) percent full"
        case .loaded(let building):
            return "\(building.name), closed"
        case .notConfigured:
            return "Building Capacity, no building chosen. Edit the widget to choose one."
        case .buildingNotFound:
            return "Building Capacity, the chosen building was not found"
        case .fetchFailed:
            return "Building Capacity, can't reach GT right now, \(WidgetText.asOf(entry.fetchedAt))"
        }
    }
}

#Preview(as: .accessoryRectangular) {
    GTCapacityPhotoWidget()
} timeline: {
    for pct in [0.12, 0.48, 0.85, 1.0] {
        GTCapacityPhotoEntry(
            date: .now, fetchedAt: .now,
            state: .loaded(CapacityPhotoData(buildingID: 0, name: "Campus Recreation Center",
                                             shortName: "CRC", percentage: pct, isOpen: true)),
            buildingID: 0
        )
    }
    GTCapacityPhotoEntry(
        date: .now, fetchedAt: .now,
        state: .loaded(CapacityPhotoData(buildingID: 0, name: "Campus Recreation Center",
                                         shortName: "CRC", percentage: 0.48, isOpen: false)),
        buildingID: 0
    )
    GTCapacityPhotoEntry(date: .now, fetchedAt: .now, state: .notConfigured, buildingID: nil)
    GTCapacityPhotoEntry(date: .now, fetchedAt: .now, state: .buildingNotFound, buildingID: 99)
    GTCapacityPhotoEntry(date: .now, fetchedAt: .now, state: .fetchFailed, buildingID: 0)
}
