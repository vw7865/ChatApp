//
//  AppTheme.swift
//  ChatAppTracker
//

import SwiftUI

enum AppTheme {
    static let background = Color(red: 0.09, green: 0.09, blue: 0.10)
    /// Deep green-black for hero headers (Last Seen, etc.).
    static let heroGradientTop = Color(red: 0.02, green: 0.07, blue: 0.05)
    /// Slightly lifted surface for list areas while staying dark/green.
    static let followedPanel = Color(red: 0.11, green: 0.13, blue: 0.11)
    static let cardFill = Color.white.opacity(0.06)
    /// Slightly brighter surface for nested cards on dark panels.
    static let nestedCardFill = Color.white.opacity(0.09)
    /// Activity statistics / log cards (~#1F1F1F).
    static let statisticsCard = Color(red: 0.12, green: 0.12, blue: 0.12)
    /// Inset pill for session duration on statistics screen.
    static let statisticsInset = Color(red: 0.07, green: 0.07, blue: 0.07)
    static let lime = Color(red: 0.58, green: 0.96, blue: 0.28)
    /// Saturated green for “online” dot and status text (separate from UI accent lime).
    static let presenceOnline = Color(red: 0.2, green: 0.78, blue: 0.38)
    static let mutedText = Color(white: 0.55)
    static let divider = Color.white.opacity(0.12)
    static let onLightFieldText = Color(red: 0.12, green: 0.14, blue: 0.14)
    /// Peach accent for the weekly plan label (paywall).
    static let weeklyAccent = Color(red: 0.98, green: 0.52, blue: 0.42)
}

extension View {
    func appThemedNavigationBar() -> some View {
        self
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
