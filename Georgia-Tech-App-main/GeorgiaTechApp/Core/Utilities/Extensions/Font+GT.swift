//
//  Font+GT.swift
//  GeorgiaTechApp
//

import SwiftUI

/// The app's type scale, from the design spec's "02. Typography" board.
/// Roboto Slab is for headings 1-3; Roboto is for everything else.
///
/// Every style is a custom font declared `relativeTo:` a system text
/// style, so it still scales with Dynamic Type. Always use these
/// instead of a bare `Font.custom` (which renders at a fixed size) or
/// a system font like `.headline`.
///
/// The spec also lists a line height per style (Heading 1 is 120%,
/// Body 3 and 4 are 1.4, the rest 1.3). `Font` cannot carry a line
/// height, so it is not applied here.
extension Font {
    // MARK: Headings

    /// Roboto Slab, 32pt, semibold.
    static let gtHeading1 = Font.custom("RobotoSlab-SemiBold", size: 32, relativeTo: .largeTitle)
    /// Roboto Slab, 24pt, semibold.
    static let gtHeading2 = Font.custom("RobotoSlab-SemiBold", size: 24, relativeTo: .title)
    /// Roboto Slab, 20pt, semibold.
    static let gtHeading3 = Font.custom("RobotoSlab-SemiBold", size: 20, relativeTo: .title3)
    /// Roboto, 16pt, semibold.
    static let gtHeading4 = Font.custom("Roboto-SemiBold", size: 16, relativeTo: .headline)
    /// Roboto, 14pt, semibold.
    static let gtHeading5 = Font.custom("Roboto-SemiBold", size: 14, relativeTo: .subheadline)
    /// Roboto, 12pt, semibold.
    static let gtHeading6 = Font.custom("Roboto-SemiBold", size: 12, relativeTo: .caption)

    // MARK: Body

    /// Roboto, 16pt, regular.
    static let gtBody1 = Font.custom("Roboto-Regular", size: 16, relativeTo: .body)
    /// Roboto, 14pt, regular.
    static let gtBody2 = Font.custom("Roboto-Regular", size: 14, relativeTo: .subheadline)
    /// Roboto, 12pt, regular.
    static let gtBody3 = Font.custom("Roboto-Regular", size: 12, relativeTo: .caption)
    /// Roboto, 10pt, regular.
    static let gtBody4 = Font.custom("Roboto-Regular", size: 10, relativeTo: .caption2)
}
