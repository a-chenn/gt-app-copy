//
//  HomeGetHelpCard.swift
//  GeorgiaTechApp
//

import SwiftUI

/// Safety resources — always the last band and always present, even
/// when every live feed is empty. Real numbers and real GT properties
/// only; calls and links confirm before leaving the app.
struct HomeGetHelpCard: View {
    private struct HelpResource: Identifiable {
        let title: String
        let subtitle: String
        let icon: String
        let urlString: String
        var id: String { title }
    }

    private static let resources: [HelpResource] = [
        HelpResource(
            title: "GT Police (Emergency)", subtitle: "404-894-2500",
            icon: "phone.fill", urlString: "tel:4048942500"),
        HelpResource(
            title: "CARE Center", subtitle: "Crisis support & referrals",
            icon: "heart.circle", urlString: "https://care.gatech.edu"),
        HelpResource(
            title: "Stamps Health Services", subtitle: "health.gatech.edu",
            icon: "cross.circle", urlString: "https://health.gatech.edu")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GTSectionHeader("Get Help")

            VStack(spacing: 0) {
                ForEach(Array(Self.resources.enumerated()), id: \.element.id) { index, resource in
                    if index > 0 {
                        Divider()
                            .padding(.leading, 48)
                    }
                    ExternalLinkButton(url: URL(string: resource.urlString)) {
                        HStack(spacing: 10) {
                            Image(systemName: resource.icon)
                                .font(.gtBody2)
                                .foregroundStyle(Color.gtAzalea)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(resource.title)
                                    .font(.gtHeading5)
                                    .foregroundStyle(Color.gtPrimaryText)
                                Text(resource.subtitle)
                                    .font(.gtBody3)
                                    .foregroundStyle(Color.gtSecondaryText)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.gtHeading6)
                                .foregroundStyle(Color.gtSecondaryText)
                        }
                        .padding(.horizontal, 14)
        .padding(.vertical, 9)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(resource.title), \(resource.subtitle)")
                    .accessibilityHint(
                        resource.urlString.hasPrefix("tel:")
                            ? "Places a phone call" : "Opens the website")
                }
            }
            .gtCard(padding: 0)
        }
    }
}
