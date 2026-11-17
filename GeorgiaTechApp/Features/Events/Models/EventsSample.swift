import Foundation

/// Temporary example feed shared by the Events page and its design previews.
enum EventsSample {
    static func makeEvents() -> [Event] {
        let samples = [EventDetailSample.event] + ClubDetailSample.upcomingEvents + [
            Event(eventID: "preview-design-workshop", title: "Figma Design Workshop",
                  location: "College of Computing", groups: ["Design Club"], imageName: "FigmaDesignWorkshop"),
            Event(eventID: "preview-volleyball", title: "Georgia Tech Volleyball",
                  location: "O’Keefe Gymnasium", groups: ["Official GT"], imageName: "GTVolleyball"),
            Event(eventID: "preview-movie-night", title: "VSA October Meeting: Movie Night",
                  location: "Kendeda 152", groups: ["Vietnamese Student Association"], imageName: "EventMovieNightCover"),
            Event(eventID: "preview-paint-sip", title: "LASO Paint & Sip",
                  location: "Tech Green", groups: ["Latin American Student Organization"], imageName: "EventPaintSipCover"),
            Event(eventID: "preview-board-games", title: "Anti-Brainrot Club Game Night",
                  location: "Crosland Tower", groups: ["Anti-Brainrot Club"], imageName: "EventBoardGameCover"),
            Event(eventID: "preview-community-service", title: "Campus Volunteer Day",
                  location: "Tech Green", groups: ["Community Service Club"]),
            Event(eventID: "preview-fundraising", title: "Campus Fundraiser",
                  location: "Student Center", groups: ["Community Service Club"]),
            Event(eventID: "preview-spirituality", title: "Reflection & Meditation",
                  location: "Reflection Room", groups: ["Meditation Club"])
        ]
        // Sample categories let the temporary example feed exercise every filter.
        let categories = ["Athletics", "Thoughtful Learning", "Group Business", "Thoughtful Learning",
                          "Athletics", "Cultural", "Arts", "Social", "Community Service", "Fundraising", "Spirituality"]
        for (index, event) in samples.enumerated() {
            // Keep the examples upcoming whenever the app or preview starts.
            event.startDate = Calendar.current.date(byAdding: .day, value: index + 1, to: .now) ?? .now
            event.endDate = event.startDate.addingTimeInterval(90 * 60)
            event.eventCategories = [categories[index]]
        }
        return samples
    }
}
