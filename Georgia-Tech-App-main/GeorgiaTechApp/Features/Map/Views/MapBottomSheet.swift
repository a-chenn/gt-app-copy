//
//  MapBottomSheet.swift
//  GeorgiaTechApp
//

import SwiftUI

/// The map's draggable bottom sheet. Hand-built rather than a system
/// `.sheet` because a presented sheet always covers the tab bar, while
/// the design has the system tab bar sitting on top of it. The panel runs
/// to the screen's bottom edge, behind the bar; its content gets the bar
/// height back as bottom safe-area padding, so lists scroll under the bar
/// and their last rows can still clear it. The host lays it out ignoring
/// the keyboard, which rises over the sheet rather than resizing it.
///
/// Below the top detent, vertical drags anywhere on the sheet resize it
/// (scrolling is locked, as with a system sheet). At the top detent its
/// lists scroll; the grabber, and anything outside a scroll view, still
/// drags it.
struct MapBottomSheet<Content: View>: View {
    let state: MapSheetState
    @ViewBuilder let content: Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Height of the tab bar covering the screen bottom.
    @State private var bottomInset: CGFloat = 0

    private let sheetShape = UnevenRoundedRectangle(
        topLeadingRadius: 32, topTrailingRadius: 32, style: .continuous)

    var body: some View {
        // The empty area passes touches through to the map.
        ZStack(alignment: .bottom) {
            Color.clear
                .allowsHitTesting(false)
            panel
        }
        .ignoresSafeArea(edges: .bottom)
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { inset in
            bottomInset = inset
        }
        // Status bar to tab bar. While the keyboard is up, the map's
        // keyboard-ignoring stack stretches above the top of the screen
        // (measured: top -107pt, not 62pt); that's not real room, so the
        // last real height is kept and the sheet doesn't grow under the
        // status bar.
        .onGeometryChange(for: Bool.self) { proxy in
            proxy.frame(in: .global).minY < 0
        } action: { isRaised in
            state.isKeyboardRaised = isRaised
        }
        .onGeometryChange(for: CGFloat?.self) { proxy in
            guard proxy.frame(in: .global).minY >= 0 else { return nil }
            return max(proxy.size.height - proxy.safeAreaInsets.bottom, 0)
        } action: { height in
            if let height {
                state.availableHeight = height
            }
        }
        .onChange(of: dynamicTypeSize.isAccessibilitySize, initial: true) { _, isLarge in
            state.railBand = isLarge ? 116 : 76
        }
    }

    private var panel: some View {
        content
            .safeAreaPadding(.bottom, bottomInset)
            .frame(maxWidth: .infinity)
            .frame(height: state.sheetHeight + bottomInset, alignment: .top)
            // Scrolled content tucks under the rounded corners, not a
            // straight line across them. At rest only the search bar
            // shows; the strip under the tab bar opens up as it lifts.
            .mask(alignment: .top) {
                sheetShape
                    .frame(height: state.sheetHeight + bottomInset * underBarReveal)
            }
            .overlay(alignment: .top) {
                grabber
            }
            .contentShape(Rectangle())
            .background {
                sheetShape
                    .fill(.regularMaterial)
                    .shadow(color: Color.gtOverlay1, radius: 12, y: -2)
            }
            .scrollDisabled(state.detent != .expanded || state.isDragging)
            // Below the top detent the drag outranks the rows, buttons and
            // search field inside, so even a fast flick that starts on one
            // moves the sheet from the first frame (taps still go through:
            // a drag only begins after 8pt of travel). At the top detent it
            // yields, so the lists scroll.
            .highPriorityGesture(dragGesture, isEnabled: state.detent != .expanded)
            .gesture(dragGesture, isEnabled: state.detent == .expanded)
    }

    /// 0 at the collapsed height, 1 once the sheet has lifted 60pt.
    private var underBarReveal: CGFloat {
        min(max((state.sheetHeight - MapSheetState.collapsedHeight) / 60, 0), 1)
    }

    private var grabber: some View {
        Capsule()
            .fill(Color.gtSecondaryText.opacity(0.4))
            .frame(width: 36, height: 5)
            .padding(.top, 6)
            .frame(width: 160, height: 20, alignment: .top)
            .contentShape(Rectangle())
            // Its own drag, which beats the scroll view underneath, so a
            // page that's all scroll view (Recents, Favorites) can still be
            // resized from the grabber at the top detent.
            .gesture(dragGesture)
            .accessibilityElement()
            .accessibilityLabel("Sheet grabber")
            .accessibilityValue(detentDescription)
            .accessibilityHint("Swipe up or down to resize the sheet")
            .accessibilityAdjustableAction { direction in
                let detents = MapSheetDetent.allCases
                guard let index = detents.firstIndex(of: state.detent) else { return }
                let next = direction == .increment ? index + 1 : index - 1
                guard detents.indices.contains(next) else { return }
                withAnimation(.smooth(duration: 0.35)) {
                    state.detent = detents[next]
                }
            }
    }

    private var detentDescription: String {
        switch state.detent {
        case .collapsed: "Collapsed"
        case .medium: "Half height"
        case .expanded: "Full height"
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                if !state.isDragging {
                    // Sideways swipes belong to the sheet's chip rows.
                    guard abs(value.translation.height) > abs(value.translation.width) else { return }
                    state.isDragging = true
                }
                state.dragTranslation = value.translation.height
            }
            .onEnded { value in
                guard state.isDragging else { return }
                settle(upwardVelocity: -value.velocity.height)
            }
    }

    /// Picks the detent the flick is heading for and springs there,
    /// carrying the finger's velocity into the animation so the release
    /// doesn't hitch.
    private func settle(upwardVelocity: CGFloat) {
        let current = state.sheetHeight
        let target = state.nearestDetent(to: current + upwardVelocity * 0.2)
        let distance = state.height(for: target) - current
        // interpolatingSpring's velocity is in units of the total distance.
        let relativeVelocity = abs(distance) > 1 ? upwardVelocity / distance : 0
        withAnimation(.interpolatingSpring(duration: 0.4, bounce: 0, initialVelocity: relativeVelocity)) {
            state.detent = target
            state.dragTranslation = 0
        }
        state.isDragging = false
    }
}

/// Keeps the map's floating buttons just above the sheet edge through
/// drags. It reads the live sheet height itself, so the map screen's
/// body (map content, queries) doesn't re-run on every drag frame.
struct MapSheetRidingButtons<Content: View>: View {
    let state: MapSheetState
    @ViewBuilder let content: Content

    var body: some View {
        if !state.isFloatingButtonsHidden {
            content
                .padding(.bottom, state.floatingButtonsBottomPadding)
                .transition(.opacity)
        }
    }
}

extension View {
    /// A horizontal chip row inside the map sheet keeps scrolling while
    /// the sheet locks vertical scrolling below its top detent.
    func mapSheetHorizontalScroll() -> some View {
        environment(\.isScrollEnabled, true)
    }
}
