//
//  LastSeenView.swift
//  ChatAppTracker
//

import SwiftUI
import UIKit
import OSLog

// MARK: - View

struct LastSeenView: View {
    @EnvironmentObject private var tracking: ContactTrackingStore

    @AppStorage(WhatsAppLinkPreferences.linkedStorageKey) private var isWhatsAppLinked = false

    @State private var activityLogContact: FollowingContact?
    @State private var confirmRemoveContact: FollowingContact?
    @State private var notificationSettingsContact: FollowingContact?
    @State private var isSideMenuOpen = false
    @State private var showAddSomeone = false
    @State private var showWhatsAppLinkInfo = false
    @State private var showUpgradeFromSlot = false
    @State private var trackingStatusContact: FollowingContact?

    var body: some View {
        GeometryReader { geo in
            let menuWidth = min(geo.size.width * 0.78, 320)
            // HStack + offset + clip so hit testing matches visible frames (offset alone leaves
            // the main stack full-width under the drawer and steals all touches).
            HStack(spacing: 0) {
                sideMenuPanel
                    .frame(width: menuWidth, alignment: .leading)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .background(sideMenuBackground)

                lastSeenMainStack
                    .frame(width: geo.size.width, height: geo.size.height)
                    .shadow(
                        color: .black.opacity(isSideMenuOpen ? 0.4 : 0),
                        radius: 16,
                        x: -6,
                        y: 0
                    )
                    .overlay {
                        if isSideMenuOpen {
                            Color.black.opacity(0.28)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    isSideMenuOpen = false
                                }
                                .accessibilityLabel("Dismiss settings")
                                .accessibilityAddTraits(.isButton)
                        }
                    }
            }
            .frame(height: geo.size.height)
            .offset(x: isSideMenuOpen ? 0 : -menuWidth)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
            .clipped()
            .animation(.spring(response: 0.35, dampingFraction: 0.88), value: isSideMenuOpen)
        }
    }

    private var sideMenuBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.07, blue: 0.11),
                AppTheme.background,
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var sideMenuPanel: some View {
        MeView(onCloseSideMenu: {
            isSideMenuOpen = false
        })
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lastSeenMainStack: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if !isWhatsAppLinked {
                        whatsAppLinkBanner
                    }

                    ForEach(tracking.allTrackedContacts()) { contact in
                        trackedContactCard(contact: contact, isOnline: contactIsOnline(contact))
                    }

                    ForEach(0..<2, id: \.self) { _ in
                        addNewSlotCard(isPremium: false)
                    }

                    ForEach(0..<2, id: \.self) { _ in
                        addNewSlotCard(isPremium: true)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                // Extra space so the last card clears the tab bar + home indicator when scrolled.
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .contentMargins(.bottom, 12, for: .scrollContent)
            .background {
                LinearGradient(
                    colors: [AppTheme.heroGradientTop, AppTheme.background],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .appThemedNavigationBar()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isSideMenuOpen.toggle()
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.body.weight(.medium))
                            .foregroundStyle(AppTheme.lime)
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image("BrandIcon")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        Text(appDisplayName)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .navigationDestination(isPresented: $showAddSomeone) {
                AddSomeoneView()
            }
            .navigationDestination(item: $activityLogContact) { contact in
                ActivityLogView(contact: contact)
            }
            .onChange(of: activityLogContact?.id) { _, newId in
                if newId != nil {
                    isSideMenuOpen = false
                }
            }
            .onChange(of: trackingStatusContact?.id) { _, newId in
                if newId != nil {
                    isSideMenuOpen = false
                }
            }
            .confirmationDialog(
                "Remove \(confirmRemoveContact?.name ?? "this contact") from tracking?",
                isPresented: Binding(
                    get: { confirmRemoveContact != nil },
                    set: { if !$0 { confirmRemoveContact = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Remove from tracking", role: .destructive) {
                    if let c = confirmRemoveContact {
                        applyRemoveContact(c)
                    }
                    confirmRemoveContact = nil
                }
                Button("Cancel", role: .cancel) {
                    confirmRemoveContact = nil
                }
            } message: {
                Text("You will stop seeing their activity here. You can add them again from Last Seen.")
            }
            .sheet(item: $notificationSettingsContact) { contact in
                ActivityNotificationSettingsSheet(contactName: contact.name)
            }
            .sheet(isPresented: $showWhatsAppLinkInfo) {
                WhatsAppLinkInfoSheet(isPresented: $showWhatsAppLinkInfo)
            }
            .sheet(item: $trackingStatusContact) { contact in
                ContactTrackingStatusSheet(contact: contact)
            }
            .fullScreenCover(isPresented: $showUpgradeFromSlot) {
                UpgradeView()
            }
        }
    }

    private var appDisplayName: String {
        if let s = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, !s.isEmpty {
            return s
        }
        if let s = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String, !s.isEmpty {
            return s
        }
        return "ChatAppTracker"
    }

    /// Red accent for the per-contact info / setup-status control (matches reference affordance).
    private var trackingInfoAccent: Color {
        Color(red: 0.92, green: 0.22, blue: 0.28)
    }

    private func contactIsOnline(_ contact: FollowingContact) -> Bool {
        contact.id == tracking.spotlightContact.id && tracking.showOnlinePerson
    }

    private func applyRemoveContact(_ contact: FollowingContact) {
        tracking.removeFromTracking(contact)
    }

    private var whatsAppLinkBanner: some View {
        Button {
            showWhatsAppLinkInfo = true
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "qrcode")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(AppTheme.lime)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Link Companion Device")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Generate a QR code, scan it from your companion app, and connect this device session.")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.07, green: 0.1, blue: 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(AppTheme.lime.opacity(0.45), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func trackedContactCard(contact: FollowingContact, isOnline: Bool) -> some View {
        HStack(alignment: .center, spacing: 0) {
            Button {
                trackingStatusContact = contact
            } label: {
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(trackingInfoAccent)
                        .frame(width: 3)
                        .padding(.vertical, 12)

                    Image(systemName: "info.circle.fill")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .symbolRenderingMode(.monochrome)
                        .frame(width: 36)
                        .frame(maxHeight: .infinity)
                        .background(trackingInfoAccent.opacity(0.22))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Setup status for \(contact.name)")

            Button {
                activityLogContact = contact
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(spacing: 6) {
                        if isOnline {
                            cardAvatarOnline(contact.initial)
                        } else {
                            cardAvatarOffline(contact.initial)
                        }
                        Text(isOnline ? "Online" : "Offline")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(
                                isOnline
                                    ? AppTheme.presenceOnline
                                    : Color(red: 0.98, green: 0.42, blue: 0.42)
                            )
                    }
                    .frame(width: 56)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(contact.name)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(contact.phoneDisplay)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.mutedText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if !isOnline {
                            Text("Last seen · \(contact.lastSeenRelative)")
                                .font(.caption)
                                .foregroundStyle(AppTheme.mutedText.opacity(0.9))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .multilineTextAlignment(.leading)

                    Spacer(minLength: 4)
                }
                .padding(.leading, 10)
                .padding(.trailing, 4)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                notificationSettingsContact = contact
            } label: {
                Image(systemName: "bell.fill")
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppTheme.lime.opacity(0.9))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                activityLogContact = contact
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedText)
                    .frame(width: 36, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.statisticsCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(AppTheme.divider, lineWidth: 1)
        )
        .contextMenu {
            Button {
                notificationSettingsContact = contact
            } label: {
                Label("Notification options", systemImage: "bell.badge")
            }
            Button(role: .destructive) {
                confirmRemoveContact = contact
            } label: {
                Label("Remove from tracking", systemImage: "person.fill.xmark")
            }
        }
    }

    private func cardAvatarOnline(_ initial: String) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Text(initial.uppercased())
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.lime)
                .frame(width: 44, height: 44)
                .background(Circle().fill(AppTheme.lime.opacity(0.14)))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
            Circle()
                .fill(AppTheme.presenceOnline)
                .frame(width: 11, height: 11)
                .overlay(Circle().strokeBorder(Color.black.opacity(0.5), lineWidth: 1))
                .offset(x: 2, y: 2)
        }
        .frame(width: 48, height: 48)
    }

    private func cardAvatarOffline(_ initial: String) -> some View {
        Text(initial.uppercased())
            .font(.subheadline.weight(.bold))
            .foregroundStyle(AppTheme.mutedText)
            .frame(width: 44, height: 44)
            .background(
                Circle()
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                Circle()
                    .strokeBorder(AppTheme.divider, lineWidth: 1)
            )
    }

    private func addNewSlotCard(isPremium: Bool) -> some View {
        Button {
            if isPremium {
                showUpgradeFromSlot = true
            } else {
                showAddSomeone = true
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                HStack(spacing: 14) {
                    if isPremium {
                        ZStack {
                            Circle()
                                .fill(AppTheme.lime.opacity(0.16))
                                .frame(width: 48, height: 48)
                            Image(systemName: "diamond.fill")
                                .font(.title3)
                                .foregroundStyle(AppTheme.lime)
                        }
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(AppTheme.mutedText.opacity(0.45))
                    }

                    Text("Click to Add New")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.92))

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity, alignment: .leading)

                if isPremium {
                    Text("PRO")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(Color.black.opacity(0.85))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(AppTheme.lime)
                        )
                        .padding(10)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.statisticsCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        isPremium ? AppTheme.lime.opacity(0.45) : AppTheme.divider,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Companion device link

private struct WhatsAppLinkInfoSheet: View {
    @Binding var isPresented: Bool
    @AppStorage(WhatsAppLinkPreferences.linkedStorageKey) private var isWhatsAppLinked = false

    @State private var viewState: CompanionLinkViewState = .idle
    @State private var linkedInstanceId: String?
    @State private var pollTask: Task<Void, Never>?
    @State private var qrExpiresAt: Date?
    @State private var successPulse = false

    private let linkName = "My Companion Session"
    private let qrLifetimeSeconds: TimeInterval = 120
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ChatAppTracker", category: "CompanionLink")

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                content
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
            .navigationTitle("Scan with WhatsApp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { isPresented = false }
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.lime)
                }
            }
        }
        .task {
            if case .idle = viewState {
                await createQRSession()
            }
        }
        .onDisappear {
            pollTask?.cancel()
            pollTask = nil
        }
        .presentationDetents([.large])
        .presentationBackground(AppTheme.background)
    }

    @ViewBuilder
    private var content: some View {
        switch viewState {
        case .idle, .loading:
            loadingCard
        case .qr(let image):
            qrCard(image: image)
        case .connected:
            connectedCard
        case .expired:
            expiredCard
        case .error(let message):
            errorCard(message: message)
        }
    }

    private var loadingCard: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 10)
            ProgressView()
                .progressViewStyle(.circular)
                .tint(AppTheme.lime)
                .scaleEffect(1.3)
            Text("Preparing secure QR code...")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.95))
            Text("Please wait while we create your companion session.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedText)
            Spacer()
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.statisticsCard.opacity(0.7))
        )
        .padding(.top, 14)
    }

    private func qrCard(image: UIImage) -> some View {
        VStack(spacing: 16) {
            Text("Scan with WhatsApp")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Open WhatsApp on your phone, go to linked devices, and scan this QR code.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedText)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(maxWidth: 340)
                .padding(16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(AppTheme.divider, lineWidth: 1)
                )
                .frame(maxWidth: .infinity)

            Group {
                if let expiresAt = qrExpiresAt {
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        let remaining = max(0, Int(expiresAt.timeIntervalSince(timeline.date)))
                        HStack(spacing: 10) {
                            ProgressView()
                                .tint(AppTheme.lime)
                            Text("Waiting for connection... \(formatRemaining(remaining))")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.mutedText)
                        }
                    }
                }
            }
            .padding(.top, 4)

            Button("Regenerate QR") {
                Task { await createQRSession() }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.lime)
            .padding(.top, 8)
        }
    }

    private var connectedCard: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 10)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(AppTheme.lime)
                .scaleEffect(successPulse ? 1.08 : 0.92)
                .symbolEffect(.bounce, value: successPulse)
                .animation(.spring(response: 0.45, dampingFraction: 0.62), value: successPulse)
            Text("Connected")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
            Text("Your companion session is active. You can now return to Last Seen.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.mutedText)
            Button {
                isWhatsAppLinked = true
                isPresented = false
            } label: {
                Text("Continue")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.black.opacity(0.88))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppTheme.lime)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
            Spacer()
        }
        .padding(.top, 14)
        .onAppear {
            successPulse = true
        }
    }

    private var expiredCard: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 10)
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 46))
                .foregroundStyle(.orange)
            Text("QR expired")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            Text("For security, this code expires after 2 minutes. Generate a new code to continue.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.mutedText)
            HStack(spacing: 12) {
                Button("Generate New QR") {
                    Task { await createQRSession() }
                }
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.black.opacity(0.88))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(AppTheme.lime)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button("Close") {
                    isPresented = false
                }
                .font(.headline.weight(.bold))
                .foregroundStyle(.white.opacity(0.92))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(AppTheme.statisticsCard)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(AppTheme.divider, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
            Spacer()
        }
        .padding(.top, 14)
    }

    private func errorCard(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer(minLength: 10)
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 46))
                .foregroundStyle(.orange)
            Text("Couldn’t create QR code")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.mutedText)
            HStack(spacing: 12) {
                Button("Try Again") {
                    Task { await createQRSession() }
                }
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.black.opacity(0.88))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(AppTheme.lime)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button("Cancel") {
                    isPresented = false
                }
                .font(.headline.weight(.bold))
                .foregroundStyle(.white.opacity(0.92))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(AppTheme.statisticsCard)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(AppTheme.divider, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
            Spacer()
        }
        .padding(.top, 14)
    }

    @MainActor
    private func createQRSession() async {
        logger.info("QR flow: create session requested")
        print("QR flow: create session requested")
        pollTask?.cancel()
        pollTask = nil
        qrExpiresAt = nil
        viewState = .loading

        do {
            let created = try await retryExponential(
                maxAttempts: 5,
                initialDelaySeconds: 0.8,
                multiplier: 2.0,
                maxDelaySeconds: 8.0
            ) {
                try await BackendAPIClient.shared.createCompanionInstance(name: linkName)
            }
            linkedInstanceId = created.id
            logger.info("QR flow: create session success instance=\(created.id, privacy: .public)")
            let image = try decodeDataURLImage(created.qrCodeDataURL)
            qrExpiresAt = Date().addingTimeInterval(qrLifetimeSeconds)
            logger.debug("QR flow: qr decoded, expires in \(Int(qrLifetimeSeconds))s")
            viewState = .qr(image: image)
            startPolling(instanceId: created.id)
        } catch {
            logger.error("QR flow: create session failed: \(String(describing: error), privacy: .public)")
            viewState = .error(errorMessage(from: error))
        }
    }

    private func startPolling(instanceId: String) {
        logger.info("QR flow: polling started instance=\(instanceId, privacy: .public)")
        pollTask = Task {
            while !Task.isCancelled {
                if let expiry = qrExpiresAt, Date() >= expiry {
                    await MainActor.run {
                        viewState = .expired
                    }
                    logger.warning("QR flow: expired before linking instance=\(instanceId, privacy: .public)")
                    return
                }
                do {
                    let status = try await BackendAPIClient.shared.fetchCompanionInstanceStatus(instanceId: instanceId)
                    if status.isLinked {
                        await MainActor.run {
                            viewState = .connected
                            isWhatsAppLinked = true
                            PushDeviceRegistrar.markNeedsUpload()
                        }
                        logger.info("QR flow: linked detected instance=\(instanceId, privacy: .public)")
                        return
                    }
                } catch {
                    logger.warning("QR flow: polling transient error instance=\(instanceId, privacy: .public) error=\(String(describing: error), privacy: .public)")
                }
                try? await Task.sleep(for: .seconds(3))
            }
            logger.debug("QR flow: polling cancelled instance=\(instanceId, privacy: .public)")
        }
    }

    private func decodeDataURLImage(_ value: String) throws -> UIImage {
        let parts = value.components(separatedBy: ",")
        let base64 = parts.count > 1 ? parts[1] : value
        guard let data = Data(base64Encoded: base64), let image = UIImage(data: data) else {
            logger.error("QR flow: QR decode failed (invalid base64 or image)")
            throw BackendAPIError.invalidQRCodeData
        }
        logger.debug("QR flow: QR decode success bytes=\(data.count)")
        return image
    }

    private func errorMessage(from error: Error) -> String {
        if let apiErr = error as? BackendAPIError {
            switch apiErr {
            case .noBaseURLConfigured:
                return "API base URL is missing. Set APIBaseURL in Info.plist."
            case .noAPIKeyConfigured:
                return "API key is missing. Set APIKey in Info.plist."
            case .httpStatus(let code):
                return "Server returned error \(code)."
            case .invalidQRCodeData:
                return "The QR image returned by the server is invalid."
            case .invalidResponse:
                return "The server returned an unexpected response."
            }
        }
        return error.localizedDescription
    }

    private func retry<T>(
        times: Int,
        delaySeconds: Double,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var attempt = 0
        var lastError: Error?
        while attempt < times {
            do {
                return try await operation()
            } catch {
                lastError = error
                attempt += 1
                if attempt < times {
                    try? await Task.sleep(for: .seconds(delaySeconds))
                }
            }
        }
        throw lastError ?? BackendAPIError.invalidResponse
    }

    private func retryExponential<T>(
        maxAttempts: Int,
        initialDelaySeconds: Double,
        multiplier: Double,
        maxDelaySeconds: Double,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var attempt = 0
        var delay = initialDelaySeconds
        var lastError: Error?

        while attempt < maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                attempt += 1
                logger.warning("QR flow: create retry attempt \(attempt)/\(maxAttempts) failed: \(String(describing: error), privacy: .public)")
                if attempt < maxAttempts {
                    let jitter = Double.random(in: 0...(delay * 0.25))
                    logger.debug("QR flow: backoff sleeping \(delay + jitter, privacy: .public)s before next retry")
                    try? await Task.sleep(for: .seconds(delay + jitter))
                    delay = min(delay * multiplier, maxDelaySeconds)
                }
            }
        }

        throw lastError ?? BackendAPIError.invalidResponse
    }

    private func formatRemaining(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%01d:%02d", minutes, seconds)
    }
}

private enum CompanionLinkViewState {
    case idle
    case loading
    case qr(image: UIImage)
    case connected
    case expired
    case error(String)
}

#Preview {
    LastSeenView()
        .environmentObject(ContactTrackingStore())
}
