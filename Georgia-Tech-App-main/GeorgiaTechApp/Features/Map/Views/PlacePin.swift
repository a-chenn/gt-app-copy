//
//  PlacePin.swift
//  GeorgiaTechApp
//

import SwiftUI

/// The single pin used for every category of place on the map.
/// Color and glyph come from `LocationCategory` — never make a
/// bespoke pin view for a new place type.
struct PlacePin: View {
    let category: LocationCategory
    var isSelected = false

    var body: some View {
        // ONE scaled transform — animating font size and frame
        // separately let the glyph jump ahead of the circle (#F5-11).
        ZStack {
            Circle()
                .fill(category.tint)
            Image(systemName: category.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(category.glyphColor)
        }
        .frame(width: 28, height: 28)
        .overlay {
            Circle().strokeBorder(Color.gtWhite, lineWidth: 2)
        }
        .shadow(color: Color.gtNavy.opacity(0.25), radius: 3, y: 1)
        .scaleEffect(isSelected ? 1.3 : 1.0)
        .animation(.spring(response: 0.32, dampingFraction: 0.75), value: isSelected)
    }
}

#Preview {
    HStack(spacing: 12) {
        PlacePin(category: .building)
        PlacePin(category: .dining, isSelected: true)
        PlacePin(category: .printer)
        PlacePin(category: .busStop)
        PlacePin(category: .parking)
    }
    .padding()
}
