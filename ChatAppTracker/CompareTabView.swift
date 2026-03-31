//
//  CompareTabView.swift
//  ChatAppTracker
//

import SwiftUI

struct CompareTabView: View {
    var body: some View {
        NavigationStack {
            ComparisonView()
        }
    }
}

#Preview {
    CompareTabView()
        .environmentObject(ContactTrackingStore())
}
