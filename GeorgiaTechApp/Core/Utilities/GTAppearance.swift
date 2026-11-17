//
//  GTAppearance.swift
//  GeorgiaTechApp
//

import SwiftUI

/// UIKit appearance for the chrome SwiftUI's `.font(...)` cannot reach.
///
/// Navigation titles, tab-bar labels, segmented controls and bar buttons
/// are drawn by UIKit, so an environment font never touches them — left
/// alone they stay San Francisco while the rest of the app is Roboto,
/// which is exactly how a font migration ends up looking half-done.
///
/// Every font here goes through `UIFontMetrics` so the chrome scales
/// with Dynamic Type just like the `Font.gtHeading*` and `Font.gtBody*` styles do.
enum GTAppearance {
    @MainActor
    static func configure() {
        let navigationBar = UINavigationBar.appearance()
        // Titles are headings: Heading 1 (large) and Heading 4 (inline).
        navigationBar.largeTitleTextAttributes = [
            .font: scaled("RobotoSlab-SemiBold", 32, .largeTitle)
        ]
        navigationBar.titleTextAttributes = [
            .font: scaled("Roboto-SemiBold", 16, .headline)
        ]

        // Bar buttons are Body 1.
        UIBarButtonItem.appearance().setTitleTextAttributes(
            [.font: scaled("Roboto-Regular", 16, .body)], for: .normal)
        UIBarButtonItem.appearance().setTitleTextAttributes(
            [.font: scaled("Roboto-SemiBold", 16, .body)], for: .highlighted)

        // Tab labels are Body 4.
        let tabItem = UITabBarItem.appearance()
        tabItem.setTitleTextAttributes([.font: scaled("Roboto-Regular", 10, .caption2)], for: .normal)
        tabItem.setTitleTextAttributes([.font: scaled("Roboto-Regular", 10, .caption2)], for: .selected)

        // Segmented controls are Body 3, with Heading 6 for the selection.
        let segmented = UISegmentedControl.appearance()
        segmented.setTitleTextAttributes(
            [.font: scaled("Roboto-Regular", 12, .caption1)], for: .normal)
        segmented.setTitleTextAttributes(
            [.font: scaled("Roboto-SemiBold", 12, .caption1)], for: .selected)

        UITextField.appearance().font = scaled("Roboto-Regular", 16, .body)
    }

    /// Bundled cut at a Dynamic Type-scaled size, falling back to the
    /// system face if a font ever fails to register.
    private static func scaled(
        _ name: String, _ size: CGFloat, _ style: UIFont.TextStyle
    ) -> UIFont {
        let base = UIFont(name: name, size: size) ?? .systemFont(ofSize: size)
        return UIFontMetrics(forTextStyle: style).scaledFont(for: base)
    }
}
