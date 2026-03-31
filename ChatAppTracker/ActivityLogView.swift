//
//  ActivityLogView.swift
//  ChatAppTracker
//

import SwiftUI

// MARK: - Shared model (also used by Last Seen list)

struct FollowingContact: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let initial: String
    let lastSeenRelative: String
    let phoneDisplay: String
    /// Calendar day when the user first had this contact in the app (activity date range starts here).
    let trackedSince: Date
}

// MARK: - Activity statistics (placeholder)

private struct ActivityStatSession: Identifiable {
    let id: String
    let startDisplay: String
    let endDisplay: String
    /// Shown in the right inset; use "-" for active / open sessions.
    let durationBadge: String
    let isActive: Bool
}

private enum ActivityLogDummyData {
    static let loginCount = 3
    static let totalDurationLabel = "45m 4s"

    static let sessions: [ActivityStatSession] = [
        ActivityStatSession(id: "1", startDisplay: "11:04:51", endDisplay: "Till now", durationBadge: "-", isActive: true),
        ActivityStatSession(id: "2", startDisplay: "09:12:03", endDisplay: "07:18:42", durationBadge: "16m 31s", isActive: false),
        ActivityStatSession(id: "3", startDisplay: "08:02:11", endDisplay: "08:26:21", durationBadge: "24m 10s", isActive: false),
        ActivityStatSession(id: "4", startDisplay: "07:41:02", endDisplay: "07:55:48", durationBadge: "14m 46s", isActive: false),
        ActivityStatSession(id: "5", startDisplay: "06:30:00", endDisplay: "06:42:18", durationBadge: "12m 18s", isActive: false),
    ]
}

struct ActivityLogView: View {
    let contact: FollowingContact

    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate: Date
    @State private var showDatePickerSheet = false

    @State private var notificationsOn = true
    @State private var confirmRemoveTracking = false
    @State private var showNotificationSettings = false
    @State private var showRefreshedNotice = false
    @State private var isRefreshing = false

    private var calendar: Calendar { Calendar.current }

    /// Start of “today” in the current calendar (used for navigation + max selectable day).
    private var startOfToday: Date {
        calendar.startOfDay(for: Date())
    }

    private var selectedDayStart: Date {
        calendar.startOfDay(for: selectedDate)
    }

    /// Earliest day stats can be shown (when this contact was added).
    private var earliestSelectableDay: Date {
        let raw = calendar.startOfDay(for: contact.trackedSince)
        return min(raw, startOfToday)
    }

    /// User can move forward only up to today.
    private var canGoToNextDay: Bool {
        selectedDayStart < startOfToday
    }

    /// User can move backward only to the add date.
    private var canGoToPreviousDay: Bool {
        selectedDayStart > earliestSelectableDay
    }

    init(contact: FollowingContact) {
        self.contact = contact
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let ear = min(cal.startOfDay(for: contact.trackedSince), today)
        let initial = min(max(today, ear), today)
        _selectedDate = State(initialValue: initial)
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    profileCard
                    weekDateStrip
                    summaryRow
                    sessionList
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
                .opacity(isRefreshing ? 0.55 : 1)
                .animation(.easeInOut(duration: 0.2), value: isRefreshing)
            }
            .scrollIndicators(.automatic)
            .refreshable {
                await refreshStatisticsAsync()
            }

            if showRefreshedNotice {
                Text("Statistics updated")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(AppTheme.statisticsCard)
                            .overlay(
                                Capsule()
                                    .strokeBorder(AppTheme.lime.opacity(0.35), lineWidth: 1)
                            )
                    )
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(Color.black)
        .ignoresSafeArea(edges: .bottom)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: showRefreshedNotice)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Back")
            }
            ToolbarItem(placement: .principal) {
                Text("Activity Statistics")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        Task { await refreshStatisticsAsync() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(isRefreshing)

                    Button {
                        showNotificationSettings = true
                    } label: {
                        Label("More notification options", systemImage: "bell.badge")
                    }

                    Button(role: .destructive) {
                        confirmRemoveTracking = true
                    } label: {
                        Label("Remove from tracking", systemImage: "person.fill.xmark")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("More options")
            }
        }
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .confirmationDialog(
            "Remove \(contact.name) from tracking?",
            isPresented: $confirmRemoveTracking,
            titleVisibility: .visible
        ) {
            Button("Remove from tracking", role: .destructive) {
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will stop seeing their activity here. You can add them again from Last Seen.")
        }
        .sheet(isPresented: $showNotificationSettings) {
            ActivityNotificationSettingsSheet(contactName: contact.name)
        }
        .sheet(isPresented: $showDatePickerSheet) {
            activityDatePickerSheet
        }
    }

    @MainActor
    private func refreshStatisticsAsync() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        try? await Task.sleep(nanoseconds: 700_000_000)
        isRefreshing = false
        showRefreshedNotice = true
        try? await Task.sleep(nanoseconds: 2_200_000_000)
        showRefreshedNotice = false
    }

    // MARK: Profile

    private var profileCard: some View {
        HStack(alignment: .center, spacing: 14) {
            squareAvatarWithOnlineBadge

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(contact.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Online")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.presenceOnline)
                }
                Text(contact.phoneDisplay.replacingOccurrences(of: " ", with: ""))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.mutedText)
            }

            Spacer(minLength: 8)

            Button {
                notificationsOn.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bell.fill")
                        .font(.subheadline)
                    Text(notificationsOn ? "On" : "Off")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(notificationsOn ? AppTheme.lime : AppTheme.mutedText)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(white: 0.08))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.statisticsCard)
        )
    }

    private var squareAvatarWithOnlineBadge: some View {
        ZStack(alignment: .bottomTrailing) {
            Text(contact.initial.uppercased())
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.lime)
                .frame(width: 56, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.lime.opacity(0.14))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                )

            Circle()
                .fill(AppTheme.presenceOnline)
                .frame(width: 14, height: 14)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 2)
                )
                .offset(x: 3, y: 3)
        }
        .frame(width: 60, height: 60)
    }

    // MARK: Date navigation (single day, no weekday strip)

    private var weekDateStrip: some View {
        HStack(spacing: 8) {
            Button {
                goToPreviousDay()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(canGoToPreviousDay ? AppTheme.lime : AppTheme.mutedText.opacity(0.35))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canGoToPreviousDay)
            .accessibilityLabel("Previous day")

            Button {
                showDatePickerSheet = true
            } label: {
                Text(activityStatisticsDateTitle)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choose date, \(activityStatisticsDateTitle)")

            Button {
                goToNextDay()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(canGoToNextDay ? AppTheme.lime : AppTheme.mutedText.opacity(0.35))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canGoToNextDay)
            .accessibilityLabel("Next day")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.statisticsCard)
        )
    }

    /// Long date style without weekday (e.g. March 29, 2026).
    private var activityStatisticsDateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = calendar.timeZone
        formatter.calendar = calendar
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: selectedDayStart)
    }

    private func goToPreviousDay() {
        guard canGoToPreviousDay else { return }
        if let previous = calendar.date(byAdding: .day, value: -1, to: selectedDayStart) {
            selectedDate = max(previous, earliestSelectableDay)
        }
    }

    private func goToNextDay() {
        guard canGoToNextDay else { return }
        if let next = calendar.date(byAdding: .day, value: 1, to: selectedDayStart) {
            selectedDate = min(next, startOfToday)
        }
    }

    /// Normalizes to start-of-day within [trackedSince, today].
    private func clampSelectedDateToValidRange(_ date: Date) -> Date {
        let start = calendar.startOfDay(for: date)
        return min(max(start, earliestSelectableDay), startOfToday)
    }

    private var activityDatePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { selectedDayStart },
                        set: { selectedDate = clampSelectedDateToValidRange($0) }
                    ),
                    in: earliestSelectableDay...startOfToday,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .navigationTitle("Select date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        selectedDate = clampSelectedDateToValidRange(selectedDate)
                        showDatePickerSheet = false
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.lime)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Color.black)
        .presentationDragIndicator(.visible)
    }

    // MARK: Summary

    private var summaryRow: some View {
        HStack(spacing: 12) {
            summaryPill(label: "Login:", value: "\(ActivityLogDummyData.loginCount)")
            summaryPill(label: "Time:", value: ActivityLogDummyData.totalDurationLabel)
        }
    }

    private func summaryPill(label: String, value: String) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.mutedText)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.lime)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.statisticsCard)
        )
    }

    // MARK: Sessions

    private var sessionList: some View {
        LazyVStack(spacing: 12) {
            ForEach(ActivityLogDummyData.sessions) { session in
                sessionRow(session)
            }
        }
    }

    private func sessionRow(_ session: ActivityStatSession) -> some View {
        HStack(alignment: .top, spacing: 12) {
            timelineColumn

            VStack(alignment: .leading, spacing: 26) {
                Text(session.startDisplay)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                Text(session.endDisplay)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(session.isActive ? AppTheme.presenceOnline : AppTheme.mutedText)
                    .monospacedDigit()
            }
            .padding(.top, 2)

            Spacer(minLength: 8)

            Text(session.durationBadge)
                .font(.caption.weight(.semibold))
                .foregroundStyle(session.durationBadge == "-" ? AppTheme.mutedText : AppTheme.lime)
                .monospacedDigit()
                .frame(minWidth: 72)
                .padding(.vertical, 12)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.statisticsInset)
                )
                .padding(.top, 4)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.statisticsCard)
        )
    }

    private var timelineColumn: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(AppTheme.lime)
                .frame(width: 10, height: 10)

            dashedConnector(height: 34)

            Circle()
                .fill(AppTheme.mutedText.opacity(0.55))
                .frame(width: 9, height: 9)
        }
        .frame(width: 14)
        .padding(.top, 6)
    }

    private func dashedConnector(height: CGFloat) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 2, height: height)
            .overlay {
                GeometryReader { geo in
                    Path { path in
                        path.move(to: CGPoint(x: 1, y: 0))
                        path.addLine(to: CGPoint(x: 1, y: geo.size.height))
                    }
                    .stroke(
                        AppTheme.mutedText.opacity(0.45),
                        style: StrokeStyle(lineWidth: 2, dash: [3, 4])
                    )
                }
            }
    }
}

// MARK: - Notification settings sheet

struct ActivityNotificationSettingsSheet: View {
    enum PresentationStyle {
        /// Single contact (Last Seen, activity log).
        case lastSeen
        /// Overlap pair (Compare tab).
        case comparison
    }

    let contactName: String
    let style: PresentationStyle

    @Environment(\.dismiss) private var dismiss

    // Last Seen
    @State private var whenComeOnline = true
    @State private var whenComeOffline = true

    // Comparison pair
    @State private var whenBothOnline = true
    @State private var whenNoLongerBothOnline = true

    @State private var quietHours = true

    init(contactName: String, style: PresentationStyle = .lastSeen) {
        self.contactName = contactName
        self.style = style
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    switch style {
                    case .lastSeen:
                        Toggle("When they come online", isOn: $whenComeOnline)
                        Toggle("When they come offline", isOn: $whenComeOffline)
                    case .comparison:
                        Toggle("When they are both online", isOn: $whenBothOnline)
                        Toggle("When they are no longer both online", isOn: $whenNoLongerBothOnline)
                    }
                } header: {
                    Text(contactName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.mutedText)
                        .textCase(nil)
                }

                Section {
                    Toggle("Quiet hours (10 PM – 8 AM)", isOn: $quietHours)
                } footer: {
                    Text("These options are placeholders until notifications are connected.")
                        .font(.caption)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Notification settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.lime)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(AppTheme.background)
    }
}

#Preview {
    NavigationStack {
        ActivityLogView(
            contact: FollowingContact(
                id: "demo",
                name: "My Daughter",
                initial: "M",
                lastSeenRelative: "now",
                phoneDisplay: "+375 12 345 678",
                trackedSince: Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
            )
        )
    }
}
