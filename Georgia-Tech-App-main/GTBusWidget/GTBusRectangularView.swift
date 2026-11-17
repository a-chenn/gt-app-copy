import SwiftUI
import WidgetKit

struct GTBusRectangularView: View {
    let entry: GTBusEntry

    var body: some View {
        AccessoryThreeLines(icon: content.icon,
                            title: content.title,
                            subtitle: content.subtitle,
                            detail: content.detail)
            .containerBackground(for: .widget) { AccessoryWidgetBackground() }
    }

    private var content: (icon: String?, title: String, subtitle: String, detail: String?) {
        switch entry.state {
        case .arrivals(let rows):
            guard let next = rows.first else {
                return ("bus", "Bus", entry.stopName, "No buses soon")
            }
            return ("bus", WidgetText.busName(next.routeName), entry.stopName,
                    WidgetText.nextIn(next.secondsToStop))
        case .noService:
            return ("bus", "Bus", entry.stopName, "No service")
        case .noArrivals:
            return ("bus", "Bus", entry.stopName, "No buses soon")
        case .checking:
            return ("bus", "Bus", entry.stopName, "Checking… " + WidgetText.asOf(entry.fetchedAt))
        case .notConfigured:
            return ("bus", "Next Bus", "Edit to choose a stop", nil)
        case .stopGone:
            return ("bus", "Bus", entry.stopName, "Stop not found")
        case .fetchFailed(let last):
            return ("bus", "Can't reach GT", entry.stopName, WidgetText.asOf(last ?? entry.fetchedAt))
        }
    }
}

#Preview(as: .accessoryRectangular) {
    GTBusWidget()
} timeline: {
    GTBusEntry(date: .now, fetchedAt: .now, stopName: "Cherry Emerson",
               state: .arrivals([BusArrivalRow(routeName: "Red Route", mapColor: "#FF0000", secondsToStop: 300)]),
               routeStopID: 1)
    GTBusEntry(date: .now, fetchedAt: .now, stopName: "Cherry Emerson", state: .checking, routeStopID: 1)
    GTBusEntry(date: .now, fetchedAt: .now, stopName: "Cherry Emerson",
               state: .fetchFailed(lastFetchedAt: .now), routeStopID: 1)
    GTBusEntry(date: .now, fetchedAt: .now, stopName: "", state: .notConfigured, routeStopID: 0)
}
