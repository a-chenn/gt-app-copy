import SwiftUI
import WidgetKit

/// Temporary events for the redesign based on the app's hardcoded club events.
/// Swap for entry.upcoming once the feed has images.
struct HardcodedEvent {
    let title: String
    let imageName: String
    let when: String

    static let pickleball = HardcodedEvent(
        title: "ASO Pickleball", imageName: "EventHomePickleballCover", when: "Today at 6:30PM")
    static let boardGames = HardcodedEvent(
        title: "Anti-Brainrot Club Game Night", imageName: "EventBoardGameCover", when: "Today at 6:30PM")
}

/// Photo with the Figma gradient: clear until 46%, then to 72% black at 93%.
struct GTEventsPhoto: View {
    let imageName: String

    var body: some View {
        Color.gtNavy
            .overlay { Image(imageName).resizable().scaledToFill() }
            .overlay {
                LinearGradient(stops: [
                    .init(color: .black.opacity(0), location: 0.4632),
                    .init(color: .black.opacity(0.72), location: 0.9332)
                ], startPoint: .top, endPoint: .bottom)
            }
            .clipped()
    }
}

/// Title above "Today at 6:30PM", 10pt apart per the Figma.
struct GTEventsEventText: View {
    let event: HardcodedEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(event.title)
                .font(.gtHeading5)
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(event.when)
                .font(.gtBody4)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .widgetAccentable()
        }
    }
}
