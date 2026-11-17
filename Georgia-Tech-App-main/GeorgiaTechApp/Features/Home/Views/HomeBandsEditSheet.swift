//
//  HomeBandsEditSheet.swift
//  GeorgiaTechApp
//

import SwiftUI

/// Rearrange the Home screen. Press and hold a row to drag it — the same
/// gesture the campus-links editor uses, so there's one way to reorder
/// things in this app.
///
/// Nothing here can be removed: a band with no data already renders
/// nothing, so hiding one would only duplicate what the feed decides.
struct HomeBandsEditSheet: View {
    @Binding var orderRaw: String
    @Environment(\.dismiss) private var dismiss

    private var bands: [HomeBand] { HomeBandStore.decode(orderRaw) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(bands) { band in
                        row(band)
                    }
                    .onMove { source, destination in
                        var updated = bands
                        updated.move(fromOffsets: source, toOffset: destination)
                        orderRaw = HomeBandStore.encode(updated)
                    }
                } header: {
                    Text("Order")
                } footer: {
                    Text("Press and hold to drag. A section with nothing to "
                         + "show today stays hidden wherever you put it.")
                }
            }
            .navigationTitle("Arrange Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        orderRaw = HomeBandStore.encode(HomeBand.defaultOrder)
                    }
                    .disabled(bands == HomeBand.defaultOrder)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(_ band: HomeBand) -> some View {
        HStack(spacing: 12) {
            Image(systemName: band.symbol)
                .font(.gtBody2)
                .foregroundStyle(Color.gtDarkGold)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(band.title)
                    .font(.gtHeading5)
                    .foregroundStyle(Color.gtPrimaryText)
                Text(band.subtitle)
                    .font(.gtBody3)
                    .foregroundStyle(Color.gtSecondaryText)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(band.title). \(band.subtitle)")
    }
}
