//
//  MapSheetState.swift
//  GeorgiaTechApp
//
//  Created by Brayden Huguenard on 7/10/26.
//

import SwiftUI

/// The map sheet's resting heights. The sheet is hand-built (not a
/// system `.sheet`) so the Map tab's system tab bar can sit on top of it.
enum MapSheetDetent: CaseIterable {
    /// Just the "Where to?" bar above the tab bar.
    case collapsed
    /// Mid height: keeps the map and its pins visible while browsing.
    case medium
    /// Full height, stopping under the chip rail.
    case expanded
}

/// Shared between the sheet and the map's floating controls, so both
/// move in the same animation transaction.
@Observable
@MainActor
final class MapSheetState {
    static let collapsedHeight: CGFloat = 72
    static let mediumHeight: CGFloat = 400

    var detent: MapSheetDetent = .collapsed
    /// Live finger travel while dragging; positive is downward.
    var dragTranslation: CGFloat = 0
    var isDragging = false
    /// Height between the status bar and the tab bar (shrinks with the
    /// keyboard, which keeps the sheet's content above it).
    var availableHeight: CGFloat = 0
    /// Room kept clear above the expanded sheet for the chip rail (~62pt;
    /// accessibility sizes need a taller band).
    var railBand: CGFloat = 76
    /// The keyboard is up. It shifts the map's layout up, which would
    /// drag the top chip rail under the status bar, so the rail hides.
    var isKeyboardRaised = false

    var expandedHeight: CGFloat {
        max(availableHeight - railBand, Self.collapsedHeight)
    }

    func height(for detent: MapSheetDetent) -> CGFloat {
        switch detent {
        case .collapsed: Self.collapsedHeight
        case .medium: min(Self.mediumHeight, expandedHeight)
        case .expanded: expandedHeight
        }
    }

    /// The visible sheet height above the tab bar, following the finger
    /// with rubber-banding past the shortest and tallest detents.
    var sheetHeight: CGFloat {
        let raw = height(for: detent) - dragTranslation
        let lower = Self.collapsedHeight
        let upper = expandedHeight
        if raw > upper { return upper + rubberBand(raw - upper) }
        if raw < lower { return lower - rubberBand(lower - raw) }
        return raw
    }

    /// The right-side bus/locate stack rides 24pt above the sheet edge.
    var floatingButtonsBottomPadding: CGFloat {
        sheetHeight + 24
    }

    /// The floating buttons would collide with the top rail once the
    /// sheet climbs past roughly 60% of the screen.
    var isFloatingButtonsHidden: Bool {
        detent == .expanded || sheetHeight > availableHeight * 0.6
    }

    /// The detent a drag released at `projectedHeight` (current height
    /// plus momentum) should settle on.
    func nearestDetent(to projectedHeight: CGFloat) -> MapSheetDetent {
        MapSheetDetent.allCases.min {
            abs(height(for: $0) - projectedHeight) < abs(height(for: $1) - projectedHeight)
        } ?? detent
    }

    /// iOS-style resistance: overshoot grows ever more slowly.
    private func rubberBand(_ overshoot: CGFloat) -> CGFloat {
        let limit: CGFloat = 60
        return limit * (1 - 1 / (overshoot / limit * 0.55 + 1))
    }
}

/// A rail category tap, handed to the sheet (which owns search state).
/// The fresh `id` lets a second tap on the same chip register.
struct MapCategoryRequest: Equatable {
    let category: SearchCategories
    let id = UUID()
}
