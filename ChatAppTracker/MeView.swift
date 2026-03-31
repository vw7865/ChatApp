//
//  MeView.swift
//  ChatAppTracker
//

import StoreKit
import SwiftUI

struct MeView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview

    @AppStorage(WhatsAppLinkPreferences.linkedStorageKey) private var isWhatsAppLinked = false

    /// When set (e.g. side drawer), shows a control to dismiss the panel.
    var onCloseSideMenu: (() -> Void)?

    @State private var showUpgrade = false
    @State private var showAbout = false
    @State private var confirmDisconnectWhatsApp = false

    init(onCloseSideMenu: (() -> Void)? = nil) {
        self.onCloseSideMenu = onCloseSideMenu
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if let close = onCloseSideMenu {
                            Button(action: close) {
                                HStack(spacing: 8) {
                                    Image(systemName: "chevron.left")
                                        .font(.body.weight(.semibold))
                                    Text("Close")
                                        .font(.body.weight(.semibold))
                                }
                                .foregroundStyle(AppTheme.lime)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Close settings")
                        }

                        profileHeader

                        settingsCard

                        Button(action: { showUpgrade = true }) {
                            HStack(spacing: 8) {
                                Text("Upgrade")
                                    .font(.headline.weight(.bold))
                                Image(systemName: "arrow.right")
                                    .font(.headline.weight(.bold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.lime)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showUpgrade) {
                UpgradeView()
            }
            .sheet(isPresented: $showAbout) {
                AboutAppSheet()
            }
            .confirmationDialog(
                "Disconnect WhatsApp?",
                isPresented: $confirmDisconnectWhatsApp,
                titleVisibility: .visible
            ) {
                Button("Disconnect", role: .destructive) {
                    isWhatsAppLinked = false
                    try? KeychainTokenStore.deleteAccessToken()
                    PushDeviceRegistrar.markNeedsUpload()
                    WhatsAppWebDataCleaner.clearWhatsAppSiteData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You’ll need to link again to use WhatsApp-based features. Use this if your session ended or you switched accounts.")
            }
        }
    }

    private var profileHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            Image("BrandIcon")
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 8) {
                Text(AppBundleInfo.displayName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text("Free")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.lime)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(AppTheme.lime.opacity(0.14))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(AppTheme.lime.opacity(0.4), lineWidth: 1)
                    )
                    .accessibilityLabel("Plan: Free")
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var settingsCard: some View {
        VStack(spacing: 0) {
            SettingsValueRow(
                icon: "info.circle.fill",
                title: "Version",
                value: AppBundleInfo.versionLine
            )
            Divider()
                .background(AppTheme.divider)
            SettingsRow(icon: "star.fill", title: "Rate app") {
                requestReview()
            }
            Divider()
                .background(AppTheme.divider)
            SettingsRow(icon: "questionmark.circle.fill", title: "About") {
                showAbout = true
            }
            Divider()
                .background(AppTheme.divider)
            SettingsRow(icon: "lifepreserver", title: "Support") {
                openURL(AppLegal.supportMailURL)
            }
            Divider()
                .background(AppTheme.divider)
            SettingsRow(icon: "hand.raised.fill", title: "Privacy Policy") {
                openURL(AppLegal.privacyPolicyURL)
            }
            Divider()
                .background(AppTheme.divider)
            SettingsRow(icon: "doc.text.fill", title: "Terms of Use") {
                openURL(AppLegal.termsOfUseURL)
            }
            Divider()
                .background(AppTheme.divider)
            SettingsRow(icon: "arrow.triangle.2.circlepath", title: "Restore") {
                restoreTapped()
            }
            if isWhatsAppLinked {
                Divider()
                    .background(AppTheme.divider)
                SettingsValueRow(
                    icon: "checkmark.circle.fill",
                    title: "WhatsApp",
                    value: "Linked"
                )
                Divider()
                    .background(AppTheme.divider)
                SettingsRow(icon: "link.badge.minus", title: "Disconnect WhatsApp") {
                    confirmDisconnectWhatsApp = true
                }
            }
        }
        .background(AppTheme.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func restoreTapped() {
        // Hook up `Transaction.currentEntitlements` / restore when ready.
    }
}

// MARK: - Bundle

private enum AppBundleInfo {
    static var displayName: String {
        if let s = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, !s.isEmpty {
            return s
        }
        if let s = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String, !s.isEmpty {
            return s
        }
        return "ChatAppTracker"
    }

    static var versionLine: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }
}

// MARK: - About sheet

private struct AboutAppSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(AppBundleInfo.displayName)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)

                    Text("Version \(AppBundleInfo.versionLine)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.lime)

                    Text("Track online activity and compare patterns across the people you follow. This screen is layout-only until live data is connected.")
                        .font(.body)
                        .foregroundStyle(AppTheme.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(AppTheme.background)
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.lime)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(AppTheme.background)
    }
}

// MARK: - Rows

private struct SettingsRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppTheme.lime)
                    .frame(width: 28, alignment: .center)
                Text(title)
                    .foregroundStyle(.white)
                    .font(.body)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsValueRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(AppTheme.lime)
                .frame(width: 28, alignment: .center)
            Text(title)
                .foregroundStyle(.white)
                .font(.body)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.mutedText)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    MeView()
}
