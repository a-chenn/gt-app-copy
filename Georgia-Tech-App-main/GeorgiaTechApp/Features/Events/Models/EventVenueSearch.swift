import Foundation

// Matches venue names for event
enum EventVenueSearch {
    static func terms(in name: String) -> Set<String> {
        let normalized = name.folding(
            options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "’", with: "")
            .replacingOccurrences(of: "'", with: "")
        let searchableName = normalizeParkingTerms(in: normalized)
        return Set(searchableName.split { !$0.isLetter && !$0.isNumber }.map(String.init))
    }

    // Prefers a complete normalized name or abbreviation over a partial name match.
    static func preferredMatches<Candidate>(
        in candidates: [Candidate], venue: String, names: (Candidate) -> [String]
    ) -> [Candidate] {
        let required = terms(in: venue)
        guard !required.isEmpty else { return [] }
        let exact = candidates.filter { candidate in
            names(candidate).contains { terms(in: $0) == required }
        }
        if !exact.isEmpty { return exact }
        // A physical venue may add "Building" to its name. Prefer that match
        // over broader listings with additional organization or department names.
        let buildingName = required.subtracting(["building"])
        if !buildingName.isEmpty {
            let buildingMatches = candidates.filter { candidate in
                names(candidate).contains { terms(in: $0).subtracting(["building"]) == buildingName }
            }
            if !buildingMatches.isEmpty { return buildingMatches }
        }
        return candidates.filter { candidate in
            names(candidate).contains { required.isSubset(of: terms(in: $0)) }
        }
    }

    static func query(for venue: String) -> String {
        let name = normalizeParkingTerms(in: venue.trimmingCharacters(in: .whitespacesAndNewlines))
        return "\(name), Georgia Tech, Atlanta"
    }

    // Translates a general parking synonym for both local matching and map searches.
    private static func normalizeParkingTerms(in name: String) -> String {
        name.replacingOccurrences(
            of: #"\bcar\s*park\b"#, with: "parking", options: [.regularExpression, .caseInsensitive])
    }
}
