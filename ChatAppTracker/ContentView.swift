//
//  ContentView.swift
//  ChatAppTracker
//
//  Created by Admin on 2026. 03. 28..
//

import SwiftUI

struct ContentView: View {
    @StateObject private var contactTracking = ContactTrackingStore()

    var body: some View {
        TabView {
            LastSeenView()
                .environmentObject(contactTracking)
                .tabItem {
                    Label("Last Seen", systemImage: "clock")
                }

            CompareTabView()
                .environmentObject(contactTracking)
                .tabItem {
                    Label("Compare", systemImage: "bubble.left.and.bubble.right")
                }
        }
        .tint(AppTheme.lime)
        .preferredColorScheme(.dark)
        .toolbarBackground(AppTheme.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
    }
}

#Preview {
    ContentView()
}
