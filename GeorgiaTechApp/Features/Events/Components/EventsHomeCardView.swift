import SwiftUI

/// Image-led event card shared by the Events home carousels and grid.
struct EventsHomeCardView: View {
    let event: Event
    var showsLocation = true

    var body: some View {
        let artwork = PlaceImageView(image: EventArtwork.imageName(for: event))
        VStack(alignment: .leading, spacing: 6) {
            artwork
                .aspectRatio(1.78, contentMode: .fit)
                .background(Color.gtGray1)
                .overlay {
                    if !artwork.hasImage {
                        Image(systemName: "calendar")
                            .font(.gtHeading1)
                            .foregroundStyle(Color.gtNavy.opacity(0.35))
                    }
                }
                .overlay(alignment: .topLeading) {
                    if showsLocation, let location = event.location, !location.isEmpty {
                        Text(location)
                            .font(.gtBody4)
                            .foregroundStyle(Color.gtNavy)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.gtWhite.opacity(0.95), in: Capsule())
                            .padding(7)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)

            Text(event.title)
                .font(.gtHeading5)
                .foregroundStyle(Color.gtPrimaryText)
                .lineLimit(1)

            Text(dateText)
                .font(.gtBody4)
                .foregroundStyle(Color.gtSecondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(event.title), \(dateText), \(event.location ?? "")")
    }

    private var dateText: String {
        let day = event.startDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        let time = event.startDate.formatted(date: .omitted, time: .shortened)
        return "\(day) · \(time)"
    }
}
