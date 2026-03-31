//
//  UpgradeView.swift
//  ChatAppTracker
//

import SwiftUI

private enum SubscriptionPlan {
    case weekly
    case yearly
}

struct UpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var selectedPlan: SubscriptionPlan = .yearly

    private let yearlyPerWeek: String = {
        let value = 39.99 / 52.0
        return String(format: "$%.2f", value)
    }()

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                ScrollView {
                    VStack(spacing: 28) {
                        brandingSection
                        featuresSection
                        plansSection
                        footerSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
    }

    private var headerBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            Button("Restore purchases", action: restoreTapped)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.mutedText)
        }
    }

    private var brandingSection: some View {
        VStack(spacing: 14) {
            Image("BrandIcon")
                .resizable()
                .scaledToFill()
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            Text("PRO")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppTheme.lime)
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            PaywallFeatureRow(
                icon: "dot.circle.fill",
                title: "Real-time online status tracking"
            )
            PaywallFeatureRow(
                icon: "trash",
                title: "Deleted message recovery"
            )
            PaywallFeatureRow(
                title: "Typing activity & read receipt insights",
                leadingIconIsDoubleCheck: true
            )
        }
    }

    private var plansSection: some View {
        VStack(spacing: 12) {
            weeklyPlanCard
            yearlyPlanCard
        }
    }

    private var weeklyPlanCard: some View {
        Button {
            selectedPlan = .weekly
        } label: {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("WEEKLY")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.weeklyAccent)
                    Text("Just $5.99 per week")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mutedText)
                }
                Spacer()
                Text("$5.99")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.mutedText)
            }
            .padding(16)
            .background(AppTheme.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        selectedPlan == .weekly ? AppTheme.lime : Color.white.opacity(0.1),
                        lineWidth: selectedPlan == .weekly ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var yearlyPlanCard: some View {
        Button {
            selectedPlan = .yearly
        } label: {
            ZStack(alignment: .topTrailing) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("YEARLY")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                        Text("Just $39.99 per year")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(yearlyPerWeek)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppTheme.lime)
                        Text("per week")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.lime)
                    }
                }
                .padding(16)
                .padding(.top, 6)

                Text("Save 86%")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.lime)
                    .clipShape(Capsule())
                    .offset(x: -4, y: -10)
            }
            .background(AppTheme.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        selectedPlan == .yearly ? AppTheme.lime : Color.white.opacity(0.1),
                        lineWidth: selectedPlan == .yearly ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var footerSection: some View {
        VStack(spacing: 14) {
            Text("Auto renewable, cancel anytime")
                .font(.caption)
                .foregroundStyle(AppTheme.mutedText)
                .multilineTextAlignment(.center)

            Button(action: continueTapped) {
                HStack(spacing: 8) {
                    Text("Continue")
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

            HStack(spacing: 0) {
                Button("Terms of Service", action: termsTapped)
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedText)
                    .underline()
                Text("  ·  ")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedText.opacity(0.7))
                Button("Privacy Policy", action: privacyTapped)
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedText)
                    .underline()
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 8)
    }

    private func continueTapped() {
        // StoreKit purchase for `selectedPlan`
    }

    private func restoreTapped() {
        // `Transaction.currentEntitlements` / restore
    }

    private func termsTapped() {
        openURL(AppLegal.termsOfUseURL)
    }

    private func privacyTapped() {
        openURL(AppLegal.privacyPolicyURL)
    }
}

private struct PaywallFeatureRow: View {
    var icon: String?
    let title: String
    var leadingIconIsDoubleCheck: Bool = false

    init(icon: String, title: String) {
        self.icon = icon
        self.title = title
        self.leadingIconIsDoubleCheck = false
    }

    init(title: String, leadingIconIsDoubleCheck: Bool) {
        self.icon = nil
        self.title = title
        self.leadingIconIsDoubleCheck = leadingIconIsDoubleCheck
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Group {
                if leadingIconIsDoubleCheck {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark")
                        Image(systemName: "checkmark")
                    }
                    .font(.subheadline.weight(.bold))
                } else if let icon {
                    Image(systemName: icon)
                        .font(.body.weight(.medium))
                }
            }
            .foregroundStyle(AppTheme.lime)
            .frame(width: 28, alignment: .center)

            Text(title)
                .font(.body)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "checkmark")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.lime)
        }
    }
}

#Preview {
    UpgradeView()
}
