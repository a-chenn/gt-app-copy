//
//  HomeMastheadView.swift
//  GeorgiaTechApp
//

import SwiftUI

/// Homepage header from the Developer Handoff Home frame.
struct HomeMastheadView: View {
    var topInset: CGFloat = 0
    var onOpenSettings: () -> Void = {}

    @ScaledMetric(relativeTo: .largeTitle) private var greetingLineHeight = 38.4
    // Roboto Slab's bundled ascent/descent span is 1.31884765625 em.
    // Trim its extra leading to the design's 1.2 em line box.
    @ScaledMetric(relativeTo: .largeTitle) private var greetingLineAdjustment = 38.4 - 32 * 1.31884765625

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                GTLockup(style: .homeHeader, height: 27.7727)

                Spacer()

                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(Color.gtSecondaryText)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
            }
            .frame(height: 44)

            Text("Hey \(AuthService.shared.currentUserFirstName()),")
                .font(.gtHeading1)
                .foregroundStyle(Color.gtPrimaryText)
                .lineSpacing(greetingLineAdjustment)
                .padding(.vertical, greetingLineAdjustment / 2)
                .frame(minHeight: greetingLineHeight, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.top, topInset + 8)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topLeading) {
            GeometryReader { proxy in
                LinearGradient(
                    colors: [Color.gtGold.opacity(0.5), Color.gtGold.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: proxy.size.width, height: 187)
                .offset(y: -12)
                .mask(alignment: .topLeading) {
                    Image("HomeHexPattern")
                        .resizable()
                        .frame(width: 1014.22, height: 483)
                        .offset(x: -205, y: -2)
                }
            }
            .frame(height: 174)
            .clipped()
            .accessibilityHidden(true)
        }
    }
}

#Preview {
    HomeMastheadView(topInset: 62)
        .background(Color.gtBackground)
}
