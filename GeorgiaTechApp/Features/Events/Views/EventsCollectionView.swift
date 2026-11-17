import SwiftUI

struct EventsCollectionView: View {
    let title: String
    let events: [Event]

    var body: some View {
        ScrollView {
            EventsGridView(events: events)
                .padding(16)
        }
        .gtScreenBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

struct EventsGridView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let events: [Event]
    var showsLocation = true

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 15),
                                 count: dynamicTypeSize.isAccessibilitySize ? 1 : 2),
                  alignment: .leading, spacing: 22) {
            ForEach(events) { event in
                NavigationLink {
                    EventDetailExampleView(event: event)
                        .toolbar(.visible, for: .navigationBar)
                } label: {
                    EventsHomeCardView(event: event, showsLocation: showsLocation)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
