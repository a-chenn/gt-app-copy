import SwiftUI
import WidgetKit

struct GTEventsMediumView: View {
    let entry: GTEventsEntry
    private let events = [HardcodedEvent.boardGames, HardcodedEvent.pickleball]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(events, id: \.title) { event in
                GTEventsEventText(event: event)
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(event.title), \(event.when)")
            }
        }
        .containerBackground(for: .widget) {
            HStack(spacing: 0) {
                ForEach(events, id: \.title) { event in
                    GTEventsPhoto(imageName: event.imageName)
                }
            }
        }
    }
}

#Preview(as: .systemMedium) {
    GTEventsWidget()
} timeline: {
    GTEventsEntry.sample()
}
