import Foundation

/// Wording shared across every widget family, so one datum reads the same everywhere.
enum WidgetText {
    /// "48%", truncating like the small widget so the numbers always agree.
    static func percent(_ fraction: Double) -> String {
        "\(Int(fraction * 100))%"
    }

    /// "as of 3:12 PM"
    static func asOf(_ date: Date) -> String {
        "as of \(date.formatted(date: .omitted, time: .shortened))"
    }

    /// "Now" / "7 min".
    static func minutes(_ seconds: Int) -> String {
        seconds < 60 ? "Now" : "\(seconds / 60) min"
    }

    /// "Red Route" -> "Red Bus"
    static func busName(_ routeName: String) -> String {
        let base = routeName.replacingOccurrences(of: " Route", with: "")
        return "\(base) Bus"
    }

    /// "Next in 5 min" / "Arriving now"
    static func nextIn(_ seconds: Int) -> String {
        seconds < 60 ? "Arriving now" : "Next in \(seconds / 60) min"
    }

    /// "1 place open" / "3 places open", same wording as the home Dining widget.
    static func placesOpen(_ count: Int) -> String {
        count == 1 ? "1 place open" : "\(count) places open"
    }
}
