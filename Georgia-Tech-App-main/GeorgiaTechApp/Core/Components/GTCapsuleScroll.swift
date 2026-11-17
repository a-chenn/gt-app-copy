//
//  GTCapsuleScroll.swift
//  GeorgiaTechApp
//

import SwiftUI

/// A horizontal row of capsules. Put `GTCategoryChip`s and icon-only `GTCapsuleButton`s inside.
///
///     GTCapsuleScroll {
///         GTCapsuleButton(icon: "heart.fill", label: "Favorites") {}
///         GTCategoryChip("Dining", icon: "fork.knife", isSelected: false) {}
///     }
struct GTCapsuleScroll<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                content
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)  // keeps the capsule shadows from being clipped
        }
    }
}

#Preview("Capsule scroll") {
    VStack(spacing: 12) {
        ForEach([false, true], id: \.self) { isSelected in
            GTCapsuleScroll {
                GTCapsuleButton(
                    icon: "heart.fill", label: "Favorites", style: isSelected ? .selected : .standard,
                    iconColor: .gtAzalea) {}
                GTCapsuleButton(
                    icon: "line.3.horizontal.decrease", label: "Filters",
                    style: isSelected ? .selected : .standard) {}
                ForEach(["Dining", "Academic", "Athletics", "Dorms", "Parking"], id: \.self) { title in
                    GTCategoryChip(title, icon: "fork.knife", isSelected: isSelected) {}
                }
            }
        }
    }
    .padding(.vertical)
    .gtScreenBackground()
}
