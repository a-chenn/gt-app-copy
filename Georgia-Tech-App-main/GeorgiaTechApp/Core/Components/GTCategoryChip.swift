//
//  GTCategoryChip.swift
//  GeorgiaTechApp
//

import SwiftUI

/// An icon and title capsule that is white at rest and navy when selected.
///
///     GTCategoryChip("Dining", icon: "fork.knife", isSelected: isDining) { isDining.toggle() }
struct GTCategoryChip: View {
    @Environment(\.controlSize) private var controlSize
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    init(_ title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: controlSize.isCompact ? 14 : 18))
                Text(title)
                    .font(controlSize.isCompact ? .gtBody2 : .gtBody1)
                    .lineLimit(1)
            }
        }
        .buttonStyle(GTCapsuleButtonStyle(style: isSelected ? .selected : .standard))
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("Category chips") {
    VStack(spacing: 16) {
        GTCategoryChip("Dining", icon: "fork.knife", isSelected: false) {}
        GTCategoryChip("Dining", icon: "fork.knife", isSelected: true) {}
    }
    .padding()
    .gtScreenBackground()
}
