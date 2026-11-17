//
//  GTLockup.swift
//  GeorgiaTechApp
//

import SwiftUI

/// The official GT lockup, sized by cap height.
///
/// Each lockup imageset ships a dark-on-light artwork and a gold/white
/// reversed one, keyed to luminosity. On a navy surface the reversed cut
/// is correct in *both* appearances — the app's color scheme says nothing
/// about what's behind this particular view — so `onDark` pins it there
/// rather than letting the ambient scheme pick the wrong artwork.
///
/// Never redraw the mark; these are the vectors the brand team ships.
struct GTLockup: View {
    @Environment(\.colorScheme) private var colorScheme

    enum Style: String {
        case oneLine = "GTLogoOneLine"
        case horizontal = "GTLogoHorizontal"
        case vertical = "GTLogoVertical"
        case extended = "GTLogoExtended"
        case homeHeader = "HomeHeaderLogo"
    }

    var style: Style = .oneLine
    var height: CGFloat = 44
    /// True when the lockup sits on navy or another dark fill.
    var onDark = false

    var body: some View {
        if style == .homeHeader {
            // Use the handoff's original alpha mask and its exact color split.
            HStack(spacing: 0) {
                Color.gtGold.frame(width: height * 49.4705 / 27.7727)
                Color.gtPrimaryText
            }
            .frame(width: height * 160.5609 / 27.7727, height: height)
            .mask {
                Image(style.rawValue)
                    .resizable()
                    .scaledToFit()
            }
            .accessibilityLabel("Georgia Tech")
        } else {
            standardLockup
        }
    }

    private var standardLockup: some View {
        Image(style.rawValue)
            .resizable()
            .scaledToFit()
            .frame(height: height)
            // Pin the reversed cut for dark fills; otherwise inherit,
            // so a lockup on an ordinary surface still tracks the app's
            // appearance instead of being stuck on the light artwork.
            .environment(\.colorScheme, onDark ? .dark : colorScheme)
            .accessibilityLabel("Georgia Tech")
            .padding(-12)
    }
}
