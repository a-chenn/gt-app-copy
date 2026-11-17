//
//  PlaceImageView.swift
//  GeorgiaTechApp
//

import SwiftUI

/// Renders a place's photo from whatever the data actually provides —
/// a bundled asset name or a remote URL — and renders nothing when the
/// place has no real image (callers decide the fallback).
struct PlaceImageView: View {
    let image: String?
    var contentMode: ContentMode = .fill

    var body: some View {
        // A `scaledToFill` image REPORTS the oversized dimension rather
        // than the size it was proposed, and `.frame(maxWidth:)` supplies
        // no upper clamp — so a wide photo used to widen its whole card
        // (a 3:1 asset measured 570pt inside a 393pt sheet, dragging every
        // sibling out of the margins with it). Color.clear takes exactly
        // the proposed size and reports exactly that, so the photo can
        // only ever overflow visually, and the clip crops it.
        Color.clear
            .overlay { fill }
            .clipped()
    }

    @ViewBuilder
    private var fill: some View {
        if let assetName, UIImage(named: assetName) != nil {
            // UIImage(named:) is a documented exception to the SwiftUI-only
            // rule (docs/DESIGN_SYSTEM.md, Enforcement): SwiftUI has no API
            // to check whether an asset-catalog image exists.
            Image(assetName)
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else if let url = remoteURL {
            AsyncImage(url: url) { phase in
                if let loaded = phase.image {
                    loaded.resizable().aspectRatio(contentMode: contentMode)
                } else {
                    Color.gtSecondaryText.opacity(0.15)
                }
            }
        }
    }

    var hasImage: Bool {
        if let assetName, UIImage(named: assetName) != nil { return true }
        return remoteURL != nil
    }

    private var isRemote: Bool {
        guard let image else { return false }
        let lowered = image.lowercased()
        return lowered.hasPrefix("http://") || lowered.hasPrefix("https://")
    }

    private var assetName: String? {
        guard let image, !isRemote else { return nil }
        return URL(fileURLWithPath: image).deletingPathExtension().lastPathComponent
    }

    private var remoteURL: URL? {
        guard let image, isRemote else { return nil }
        return URL(string: image)
    }
}
