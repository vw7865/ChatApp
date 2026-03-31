//
//  ContactTrackingStatusSheet.swift
//  ChatAppTracker
//

import SwiftUI

/// Explains setup stages for a tracked number (layout-only; no Live Support).
struct ContactTrackingStatusSheet: View {
    let contact: FollowingContact
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(contact.name.uppercased())
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)

                    Text(contact.phoneDisplay)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.white.opacity(0.92))

                    Text("The following indicates the stage your number is at")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mutedText)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 18) {
                        trackingStatusRow(
                            isSuccess: true,
                            title: "Valid Number",
                            detail: "It is checked whether the number is registered in WhatsApp or not."
                        )

                        trackingStatusRow(
                            isSuccess: true,
                            title: "Number transferred to service",
                            detail: "Tracking is carried out by our services and the number must be assigned to a service. (May take a few minutes.)"
                        )

                        trackingStatusRow(
                            isSuccess: false,
                            title: "Token not found or expired",
                            detail: "For tracking to work, the token information created by WhatsApp must be received. It is enough to receive a message from the person you follow."
                        )
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(AppTheme.background)
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
        .presentationDragIndicator(.visible)
    }

    private func trackingStatusRow(isSuccess: Bool, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(isSuccess ? AppTheme.presenceOnline : Color(red: 0.95, green: 0.32, blue: 0.35))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.statisticsCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppTheme.divider, lineWidth: 1)
        )
    }
}

#Preview {
    ContactTrackingStatusSheet(
        contact: FollowingContact(
            id: "p",
            name: "John",
            initial: "J",
            lastSeenRelative: "—",
            phoneDisplay: "+1 587 715 1310",
            trackedSince: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        )
    )
}
