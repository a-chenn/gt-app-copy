import Foundation

/// Explicit fixture for design previews; never inserted into the live feed.
enum EventDetailSample {
    static var event: Event {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        let start = calendar.date(from: DateComponents(
            year: 2026, month: 12, day: 8, hour: 18, minute: 30)) ?? .now
        return Event(
            eventID: "sample-aso-pickleball",
            title: "ASO Pickleball",
            body: """
            Join the Arab Student Organization for a fun pickleball event filled with friendly competition, good vibes, and a chance to hang out with friends!
            Whether you’re a pickleball pro, trying it for the first time, or just coming to cheer and socialize, everyone is welcome.
            Bring your friends, come ready to play, and enjoy a relaxed night with ASO.
            Open to all students — we hope to see you there!
            """,
            location: "Peters Parking Deck",
            startDate: start,
            endDate: start.addingTimeInterval(2 * 60 * 60),
            groups: ["Arab Student Association"],
            imageName: "EventHomePickleballCover"
        )
    }
}
