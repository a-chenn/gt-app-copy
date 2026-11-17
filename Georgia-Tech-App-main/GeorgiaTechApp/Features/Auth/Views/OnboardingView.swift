//
//  Onboarding.swift
//  GeorgiaTechApp
//

import SwiftUI

struct OnboardingView: View {
    @Environment(\.colorScheme) private var colorScheme
    /// Called when the user skips or finishes the carousel.
    let onFinish: () -> Void

    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Maps",
            subtitle: "Live tracking of bus routes. Get directions to campus buildings. Report road blocks."
        ),
        OnboardingPage(
            title: "Calendar",
            subtitle: "View course schedules. Browse and add events to calendar. Read the latest news."
        ),
        OnboardingPage(
            title: "Dining",
            subtitle: "Get directions to dining locations. View menus. Search for nearby printers."
        )
    ]

    private var isLastPage: Bool { page == pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            // Small skip button, top corner (slides 1 and 2 only).
            HStack {
                Spacer()
                Button(action: onFinish) {
                    Text("Skip")
                        .font(.gtHeading5)
                        .foregroundStyle(Color.gtSecondaryText)
                }
                .opacity(isLastPage ? 0 : 1)
                .disabled(isLastPage)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .frame(height: 32)

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            // System dots are hidden; the dash indicator below replaces them.
            .tabViewStyle(.page(indexDisplayMode: .never))

            PageDashes(count: pages.count, current: page)
                .padding(.top, 8)
                .padding(.bottom, 20)

            // Large done button, last slide only.
            Button(action: onFinish) {
                Text("DONE")
                    .font(.gtHeading4)
                    .tracking(1)
                    .foregroundStyle(Color.gtNavy)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.gtGold, in: Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .opacity(isLastPage ? 1 : 0)
            .disabled(!isLastPage)
            .animation(.easeInOut(duration: 0.2), value: isLastPage)
        }
        .background((colorScheme == .dark ? Color.gtNavy : Color.gtWhite).ignoresSafeArea())
    }
}

// MARK: - Page indicator

private struct PageDashes: View {
    @Environment(\.colorScheme) private var colorScheme
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? (colorScheme == .dark ? Color.gtGold : Color.gtDarkGold) : Color.gtSecondaryText.opacity(0.35))
                    .frame(width: index == current ? 28 : 10, height: 6)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(current + 1) of \(count)")
    }
}

// MARK: - Supporting types

private struct OnboardingPage: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gtNavy.opacity(0.1))
                .frame(width: 240, height: 240)
                .overlay(
                    Text("Feature Image\nPlaceholder")
                        .font(.gtBody1)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.gtSecondaryText)
                )

            Spacer()

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.gtHeading2)
                    .foregroundStyle(Color.gtPrimaryText)

                Text(page.subtitle)
                    .font(.gtBody1)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.gtSecondaryText)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
