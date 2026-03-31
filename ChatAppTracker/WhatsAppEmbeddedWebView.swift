//
//  WhatsAppEmbeddedWebView.swift
//  ChatAppTracker
//

import SwiftUI
import WebKit

/// Embedded browser for WhatsApp Web (official QR / phone-number linking UI).
struct WhatsAppEmbeddedWebView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(WhatsAppLinkPreferences.linkedStorageKey) private var isWhatsAppLinked = false

    /// Called after the user confirms linking so the parent can dismiss any covering sheets.
    var onLinkedSuccessfully: (() -> Void)?

    init(onLinkedSuccessfully: (() -> Void)? = nil) {
        self.onLinkedSuccessfully = onLinkedSuccessfully
    }

    var body: some View {
        NavigationStack {
            WhatsAppWebViewRepresentable()
                .background(Color(red: 0.06, green: 0.08, blue: 0.1))
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("WhatsApp Web")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(AppTheme.background, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.lime)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("I'm linked — continue") {
                            isWhatsAppLinked = true
                            dismiss()
                            onLinkedSuccessfully?()
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.lime)
                    }
                }
        }
        .preferredColorScheme(.dark)
    }
}

private struct WhatsAppWebViewRepresentable: UIViewRepresentable {
    private static let webURL = URL(string: "https://web.whatsapp.com/")!

    /// Desktop Safari–style UA so WhatsApp more often serves the real web client (QR / link with phone) instead of a mobile-only interstitial.
    private static let preferredUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15"

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = Self.preferredUserAgent
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.load(URLRequest(url: Self.webURL))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}

// MARK: - Site data (disconnect / fresh link)

enum WhatsAppWebDataCleaner {
    /// Clears stored website data for WhatsApp domains so the next in-app Web session starts clean after a disconnect.
    static func clearWhatsAppSiteData(completion: (() -> Void)? = nil) {
        let store = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        store.fetchDataRecords(ofTypes: types) { records in
            let targets = records.filter { $0.displayName.lowercased().contains("whatsapp") }
            guard !targets.isEmpty else {
                DispatchQueue.main.async { completion?() }
                return
            }
            store.removeData(ofTypes: types, for: targets) {
                DispatchQueue.main.async { completion?() }
            }
        }
    }
}

#Preview {
    WhatsAppEmbeddedWebView()
}
