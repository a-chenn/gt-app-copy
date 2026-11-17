//
//  ReportIssue.swift
//  GeorgiaTechApp
//

import Foundation

/// "Report an Issue" routes to a configured email (REPORTEMAIL in
/// Secrets.plist). No backend endpoint exists for reports yet — when the
/// key is absent the action is hidden entirely rather than faked.
enum ReportIssue {
    static let email: String? = {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let email = dict["REPORTEMAIL"] as? String,
              // A copied-over example placeholder must not count as
              // configured — require something email-shaped.
              email.contains("@"), !email.contains(" ")
        else { return nil }
        return email
    }()

    static var isConfigured: Bool { email != nil }

    static func mailURL(for place: SearchCardModel) -> URL? {
        let body = """
        Place: \(place.title)
        Category: \(place.category.label)
        ID: \(place.id)

        What's wrong (stale hours, closed, wrong location, ...):

        """
        return mailURL(subject: "GT App issue report: \(place.title)", body: body)
    }

    /// Settings → Support rows (feedback, bug reports, feature requests).
    static func supportMailURL(subject: String) -> URL? {
        mailURL(subject: subject, body: "")
    }

    private static func mailURL(subject: String, body: String) -> URL? {
        guard let email else { return nil }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url
    }
}
