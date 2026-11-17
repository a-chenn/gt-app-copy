//
//  SearchCategoryChip.swift
//  GeorgiaTechApp
//
//  Created by Brayden Huguenard on 7/10/26.
//

import SwiftUI

struct SearchCategoryChip: View {
    let category: SearchCategories
    var isSelected = false
    /// True when the chip floats over the MAP (the amenity rail): the
    /// unselected state gets a glass backing for legibility over tiles.
    /// In the sheet it stays a stroked capsule — one component, one
    /// selection language, two surfaces.
    var onGlass = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isSelected {
                chipLabel
                    .background(Color.gtGold, in: .capsule)
            } else if onGlass {
                // Material, not glass — glass draws a drop shadow that
                // reads as a smudge over light map tiles (#F5-9).
                chipLabel
                    .background(.regularMaterial, in: .capsule)
                    .overlay {
                        Capsule().strokeBorder(Color.gtSecondaryText.opacity(0.25), lineWidth: 1)
                    }
            } else {
                // Same language as the filter pills (#19) — glass reads as
                // a gray smear against the sheet in light mode.
                chipLabel
                    .background {
                        Capsule().strokeBorder(Color.gtSecondaryText.opacity(0.4), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(category.title) category")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var chipLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: category.systemImage)

            Text(category.title)
                .fontWeight(.medium)
        }
        .font(.gtBody2)
        .foregroundStyle(isSelected ? Color.gtNavy : Color.gtPrimaryText)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

#Preview {
    HStack {
        SearchCategoryChip(category: .dining, action: {})
        SearchCategoryChip(category: .dining, isSelected: true, action: {})
    }
}
