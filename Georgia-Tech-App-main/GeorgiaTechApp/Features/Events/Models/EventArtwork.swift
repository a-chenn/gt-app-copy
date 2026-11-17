import Foundation

/// Temporary user-supplied photos for matching events whose feed contains no artwork.
enum EventArtwork {
    static func imageName(for event: Event) -> String {
        if !event.imageName.isEmpty { return event.imageName }
        let title = event.title.lowercased()
        if title.contains("pickleball") { return "EventHomePickleballCover" }
        if title.contains("movie") || title.contains("film night") { return "EventMovieNightCover" }
        if title.contains("paint") && title.contains("sip") { return "EventPaintSipCover" }
        if title.contains("board game") || title.contains("boardgame") || title.contains("brainrot") {
            return "EventBoardGameCover"
        }
        return ""
    }
}
