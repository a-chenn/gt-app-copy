import SwiftUI
import WidgetKit

struct GTEventsSmallView: View {
    let entry: GTEventsEntry
    private let event = HardcodedEvent.pickleball

    var body: some View {
        GTEventsEventText(event: event)
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .containerBackground(for: .widget) { GTEventsPhoto(imageName: event.imageName) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(event.title), \(event.when)")
    }
}

#Preview(as: .systemSmall) {
    GTEventsWidget()
} timeline: {
    GTEventsEntry.sample()
}
