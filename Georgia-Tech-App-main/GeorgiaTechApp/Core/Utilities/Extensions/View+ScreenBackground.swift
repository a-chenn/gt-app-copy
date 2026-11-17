//
//  View+ScreenBackground.swift
//  GeorgiaTechApp
//

import SwiftUI

extension View {
    /// The screen background behind every scrolling screen, so cards
    /// read as cards on top of it.
    func gtScreenBackground() -> some View {
        background {
            Color.gtBackground
                .ignoresSafeArea()
        }
    }
}
