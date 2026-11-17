//
//  WrappingHStack.swift
//  GeorgiaTechApp
//
//  Created by Drew Mendelow on 11/5/26.
//
import SwiftUI

struct WrappingHStack: Layout {
    var spacing: CGFloat = 3
    var maxWidth: CGFloat = 159

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let availableWidth = min(proposal.width ?? maxWidth, maxWidth)
        let result = calculateLayout(subviews, maxWidth: availableWidth)

        return result.size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = calculateLayout(subviews, maxWidth: bounds.width)

        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(
                    x: bounds.minX + position.x,
                    y: bounds.minY + position.y
                ),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }

    private func calculateLayout(
        _ subviews: Subviews,
        maxWidth: CGFloat
    ) -> (size: CGSize, positions: [CGPoint], sizes: [CGSize]) {
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []

        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var contentWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: x, y: y))
            sizes.append(size)

            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            contentWidth = max(contentWidth, x - spacing)
        }

        return (
            CGSize(width: contentWidth, height: y + rowHeight),
            positions,
            sizes
        )
    }
}
