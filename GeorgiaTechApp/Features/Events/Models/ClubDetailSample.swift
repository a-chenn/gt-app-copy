import Foundation

/// Screenshot content for the standalone club design example; never inserted into the live feed.
enum ClubDetailSample {
    static let name = "iOS Club @ GT"
    static let buildingName = "College of Computing"
    static let roomNumber = "016"
    static let description = """
    iOS Club is an organization which aims to provide a community for passionate iOS developers developing apps together. We provide flexible ways for students to build their iOS development skills, whether you’re just getting started or already have apps published on the App Store. Our diverse alumni network also serves as an opportunity for students to meet top engineers in the industry.
    """
    static let audience = "Undergraduate Students\nGraduate Students\nInternational Students\nTransfer Students"
    static let dues = "None"
    static let meetingFormat = "In-Person\nVirtually\nHybrid"

    static var upcomingEvents: [Event] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        let start = calendar.date(from: DateComponents(
            year: 2026, month: 10, day: 12, hour: 17)) ?? .now
        let welcomeStart = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        let projectStart = calendar.date(byAdding: .day, value: 14, to: start) ?? start

        return [
            Event(
                eventID: "sample-ios-club-speaker-christina-zhao",
                title: "Speaker Series: Christina Zhao",
                location: "\(buildingName) \(roomNumber)",
                startDate: start,
                endDate: start.addingTimeInterval(90 * 60),
                groups: [name],
                imageName: "ClubSpeakerChristinaZhao"
            ),
            Event(
                eventID: "sample-ios-club-welcome-meeting",
                title: "iOS Club Welcome Meeting",
                location: "\(buildingName) \(roomNumber)",
                startDate: welcomeStart,
                endDate: welcomeStart.addingTimeInterval(60 * 60),
                groups: [name],
                imageName: "iOSWelcomeMeeting"
            )
        ]
    }
}
