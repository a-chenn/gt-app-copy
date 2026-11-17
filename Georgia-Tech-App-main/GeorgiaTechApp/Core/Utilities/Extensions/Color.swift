//
//  Color.swift
//  GeorgiaTechApp
//
//  Created by Brayden Huguenard on 7/10/26.
//

import SwiftUI

/// The app's color palette. Every name carries the `gt` prefix so none
/// can collide with an Apple system color, and every value is taken
/// from the design spec's "01. Color" board: core, secondary, accent
/// and gradient colors are Georgia Tech's official brand values; the
/// rest (text, background, status, gray, overlay, map) are the spec's
/// "colors pending approval". This is the ONLY palette in the app.
extension Color {
    // MARK: - Core colors (official GA Tech colors)

    static let gtGold = Color(hex: "B39051")
    static let gtWhite = Color(hex: "FFFFFF")
    static let gtDarkGold = Color(hex: "8F713D")
    static let gtNavy = Color(hex: "051E39")

    // MARK: - Secondary colors (official GA Tech colors)

    static let gtDiploma = Color(hex: "F9F6E5")
    static let gtBuzz = Color(hex: "EAAA00")

    // MARK: - Accent colors (official GA Tech colors)

    static let gtCampanile = Color(hex: "048A81")
    static let gtBurdell = Color(hex: "BBE6F2")
    static let gtTechLawn = Color(hex: "066034")
    static let gtWhistle = Color(hex: "660064")
    static let gtAzalea = Color(hex: "D90368")

    // MARK: - Gradient colors (official GA Tech colors)
    //
    // The stops behind `gtGoldGradient` and `gtNavyGradient`.

    static let gtLightGold = Color(hex: "DEBD88")
    static let gtMediumNavy = Color(hex: "003D69")
    static let gtBrightBlue = Color(hex: "004C97")

    // MARK: - Colors pending approval
    //
    // Text and background carry the spec's value in light mode and
    // fall back to the matching iOS semantic color in dark mode: the
    // spec defines no dark palette, and a fixed #242424 would be
    // unreadable on a black background.

    static let gtPrimaryText = adaptive(light: "242424", dark: UIColor.label)
    static let gtSecondaryText = adaptive(light: "515151", dark: UIColor.secondaryLabel)
    static let gtBackground = adaptive(light: "F4F4F4", dark: UIColor.systemBackground)

    static let gtRed = Color(hex: "DE1010")
    static let gtGreen = Color(hex: "04924B")

    /// Featured-event text from the Developer Handoff Home frame.
    static let gtFeaturedEventText = Color(hex: "F1F1F1")

    static let gtGray1 = Color(hex: "E9EAE9")
    static let gtGray2 = Color(hex: "AAAAAA")

    /// Black at 10%.
    static let gtOverlay1 = Color(hex: "000000").opacity(0.10)
    /// Black at 5%.
    static let gtOverlay2 = Color(hex: "000000").opacity(0.05)
    /// White at 80%.
    static let gtMapWhite = Color(hex: "FFFFFF").opacity(0.80)
    /// White at 60%.
    static let gtMapGlass = Color(hex: "FFFFFF").opacity(0.60)

    private static func adaptive(light hex: String, dark: UIColor) -> Color {
        let lightColor = UIColor(Color(hex: hex))
        return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : lightColor
        })
    }

    init(hex: String) {
        var rgb: UInt64 = 0
        let cleanedHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        Scanner(string: cleanedHex).scanHexInt64(&rgb)

        let red = Double((rgb >> 16) & 0xFF) / 255.0
        let green = Double((rgb >> 8) & 0xFF) / 255.0
        let blue = Double(rgb & 0xFF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}

// MARK: - Gradients

/// The spec's two gradient swatches. Usable as a shorthand in any
/// ShapeStyle position (`.fill(.gtGoldGradient)`) or explicitly
/// (`LinearGradient.gtGoldGradient`).
extension ShapeStyle where Self == LinearGradient {
    /// Dark Gold → Gold → Light Gold → Dark Gold.
    static var gtGoldGradient: LinearGradient {
        LinearGradient(
            colors: [.gtDarkGold, .gtGold, .gtLightGold, .gtDarkGold],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Navy → Medium Navy → Bright Blue → Navy.
    static var gtNavyGradient: LinearGradient {
        LinearGradient(
            colors: [.gtNavy, .gtMediumNavy, .gtBrightBlue, .gtNavy],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
