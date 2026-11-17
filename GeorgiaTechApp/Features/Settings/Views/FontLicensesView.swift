//
//  FontLicensesView.swift
//  GeorgiaTechApp
//

import SwiftUI

/// The app bundles Roboto (SIL Open Font License 1.1) and Roboto Slab
/// (Apache License 2.0). Both licenses require the notice to travel
/// with the software, so the texts ship in the bundle and are shown
/// here rather than only living in the repo.
struct FontLicensesView: View {
    private struct Notice: Identifiable {
        let title: String
        let resource: String
        var id: String { resource }
    }

    private static let notices = [
        Notice(title: "Roboto — SIL Open Font License 1.1", resource: "Roboto-OFL"),
        Notice(title: "Roboto Slab — Apache License 2.0", resource: "RobotoSlab-Apache-2.0")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Typefaces are used per Georgia Tech's brand guidance for digital media.")
                    .font(.gtBody2)
                    .foregroundStyle(Color.gtSecondaryText)

                ForEach(Self.notices) { notice in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(notice.title)
                            .font(.gtHeading4)
                            .foregroundStyle(Color.gtPrimaryText)

                        Text(Self.text(for: notice.resource))
                            .font(.gtBody4)
                            .foregroundStyle(Color.gtSecondaryText)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(16)
        }
        .gtScreenBackground()
        .navigationTitle("Font Licenses")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Reads the bundled license text; the fallback keeps the required
    /// attribution visible even if a resource ever goes missing.
    private static func text(for resource: String) -> String {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "txt"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return "License text unavailable. Roboto and Roboto Slab are "
                + "© The Roboto Project Authors, licensed under the SIL Open "
                + "Font License 1.1 and the Apache License 2.0 respectively."
        }
        return contents
    }
}

#Preview {
    NavigationStack {
        FontLicensesView()
    }
}
