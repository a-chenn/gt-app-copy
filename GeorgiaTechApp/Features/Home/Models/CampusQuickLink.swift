//
//  CampusQuickLink.swift
//  GeorgiaTechApp
//

import Foundation

/// One home-screen campus link: either a catalog pick or a link the
/// user created themselves. The pinned set + order persist as a JSON
/// string in `@AppStorage("homeQuickLinksV2")` (Codable — custom links
/// transparently on first read.
struct CampusQuickLink: Identifiable, Equatable, Codable {
    let id: String
    var title: String
    var icon: String
    var urlString: String
    var isCustom = false

    /// Every pinnable catalog link. All real, stable gatech.edu
    /// properties.
    static let catalog: [CampusQuickLink] = [
        CampusQuickLink(
            id: "library", title: "Library", icon: "books.vertical",
            urlString: "https://library.gatech.edu"),
        CampusQuickLink(
            id: "stamps", title: "Stamps Health", icon: "cross.circle",
            urlString: "https://health.gatech.edu"),
        CampusQuickLink(
            id: "mental-health", title: "Mental Health", icon: "brain.head.profile",
            urlString: "https://counseling.gatech.edu"),
        CampusQuickLink(
            id: "eaccount", title: "eAccount", icon: "dollarsign.circle",
            urlString: "https://eaccount.gatech.edu"),
        CampusQuickLink(
            id: "crc", title: "CRC", icon: "dumbbell",
            urlString: "https://crc.gatech.edu"),
        CampusQuickLink(
            id: "stingerette", title: "Stingerette", icon: "bus",
            urlString: "https://pts.gatech.edu/stingerette"),
        CampusQuickLink(
            id: "canvas", title: "Canvas", icon: "graduationcap",
            urlString: "https://canvas.gatech.edu"),
        CampusQuickLink(
            id: "buzzport", title: "BuzzPort", icon: "person.crop.square",
            urlString: "https://buzzport.gatech.edu"),
        CampusQuickLink(
            id: "parking", title: "Parking (PTS)", icon: "parkingsign",
            urlString: "https://pts.gatech.edu"),
        CampusQuickLink(
            id: "dining", title: "GT Dining", icon: "fork.knife",
            urlString: "https://dining.gatech.edu"),
        CampusQuickLink(
            id: "career", title: "Career Center", icon: "briefcase",
            urlString: "https://career.gatech.edu"),
        CampusQuickLink(
            id: "housing", title: "Housing", icon: "building.2",
            urlString: "https://housing.gatech.edu")
    ]

    /// The out-of-the-box six (the old sidebar's set).
    static let defaultIDs = [
        "library", "stamps", "mental-health", "eaccount", "crc", "stingerette"
    ]

    /// Builds a user-created link from raw form input; nil when the URL
    /// can't become a plausible https link.
    static func custom(title: String, urlText: String) -> CampusQuickLink? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        var address = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !address.isEmpty else { return nil }
        if !address.lowercased().hasPrefix("http://") && !address.lowercased().hasPrefix("https://") {
            address = "https://" + address
        }
        guard let url = URL(string: address), let host = url.host(), host.contains(".") else {
            return nil
        }
        return CampusQuickLink(
            id: "custom-\(UUID().uuidString)",
            title: trimmedTitle, icon: "link", urlString: address, isCustom: true)
    }
}

/// Encode/decode the pinned list.
enum QuickLinkStore {
    static func decode(_ raw: String) -> [CampusQuickLink] {
        if let data = raw.data(using: .utf8),
           let links = try? JSONDecoder().decode([CampusQuickLink].self, from: data) {
            return links
        }
        return CampusQuickLink.defaultIDs.compactMap { id in
            CampusQuickLink.catalog.first { $0.id == id }
        }
    }

    static func encode(_ links: [CampusQuickLink]) -> String {
        guard let data = try? JSONEncoder().encode(links),
              let encoded = String(bytes: data, encoding: .utf8) else { return "" }
        return encoded
    }
}
