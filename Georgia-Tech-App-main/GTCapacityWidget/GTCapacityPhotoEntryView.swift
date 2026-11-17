import SwiftUI
import WidgetKit

struct GTCapacityPhotoEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GTCapacityPhotoEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            GTCapacityRectangularView(entry: entry)
                .widgetURL(
                    entry.buildingID.flatMap { URL(string: "gtapp://capacities?id=\($0)") }
                    ?? URL(string: "gtapp://capacities")
                )
        default:
            GTCapacityPhotoMediumView(entry: entry)
        }
    }
}
