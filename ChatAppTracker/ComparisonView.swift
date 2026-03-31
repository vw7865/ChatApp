//
//  ComparisonView.swift
//  ChatAppTracker
//

import SwiftUI

private func comparisonPairs(from people: [FollowingContact]) -> [ComparisonPair] {
    guard people.count >= 2 else { return [] }
    var pairs: [ComparisonPair] = []
    for i in 0..<people.count {
        for j in (i + 1)..<people.count {
            pairs.append(ComparisonPair(contactA: people[i], contactB: people[j]))
        }
    }
    return pairs
}

struct ComparisonPair: Hashable, Identifiable {
    let contactA: FollowingContact
    let contactB: FollowingContact

    var id: String {
        [contactA.id, contactB.id].sorted().joined(separator: "|")
    }

    var pairDisplayTitle: String {
        "\(contactA.name) & \(contactB.name)"
    }
}

private struct PairNotificationContext: Identifiable {
    let id: String
    let contactNameForSheet: String
}

// MARK: - Hub

struct ComparisonView: View {
    @EnvironmentObject private var tracking: ContactTrackingStore

    @State private var firstPick: FollowingContact?
    @State private var secondPick: FollowingContact?
    @State private var hiddenPairIds: Set<String> = []
    @State private var notificationContext: PairNotificationContext?
    @State private var pairPendingRemoval: ComparisonPair?

    private var trackedPeople: [FollowingContact] {
        tracking.allTrackedContacts()
    }

    private var allPairs: [ComparisonPair] {
        comparisonPairs(from: trackedPeople)
    }

    private var visiblePairs: [ComparisonPair] {
        allPairs.filter { !hiddenPairIds.contains($0.id) }
    }

    private var canOpenManualComparison: Bool {
        guard let a = firstPick, let b = secondPick else { return false }
        return a.id != b.id
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                personPickerCard(
                    title: "First person",
                    selection: $firstPick
                )

                personPickerCard(
                    title: "Second person",
                    selection: $secondPick
                )

                if canOpenManualComparison, let a = firstPick, let b = secondPick {
                    NavigationLink(value: ComparisonPair(contactA: a, contactB: b)) {
                        Text("View comparison")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.black.opacity(0.88))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.lime)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                } else {
                    Text("View comparison")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.mutedText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.statisticsCard)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(AppTheme.divider, lineWidth: 1)
                        )
                }

                Text("Following")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.top, 8)

                comparePairsListSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.automatic)
        .background(
            LinearGradient(
                colors: [Color.black, AppTheme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(for: ComparisonPair.self) { pair in
            ComparisonDetailView(contactA: pair.contactA, contactB: pair.contactB)
        }
        .sheet(item: $notificationContext) { ctx in
            ActivityNotificationSettingsSheet(contactName: ctx.contactNameForSheet, style: .comparison)
        }
        .confirmationDialog(
            "Remove pair from list?",
            isPresented: Binding(
                get: { pairPendingRemoval != nil },
                set: { if !$0 { pairPendingRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove from tracking", role: .destructive) {
                if let p = pairPendingRemoval {
                    hiddenPairIds.insert(p.id)
                }
                pairPendingRemoval = nil
            }
            Button("Cancel", role: .cancel) {
                pairPendingRemoval = nil
            }
        } message: {
            if let p = pairPendingRemoval {
                Text("\(p.pairDisplayTitle) will be removed from this compare list.")
            }
        }
        .onChange(of: trackedPeople.map(\.id)) { _, _ in
            hiddenPairIds = hiddenPairIds.filter { id in
                allPairs.contains(where: { $0.id == id })
            }
            if let fp = firstPick, !trackedPeople.contains(where: { $0.id == fp.id }) {
                firstPick = nil
            }
            if let sp = secondPick, !trackedPeople.contains(where: { $0.id == sp.id }) {
                secondPick = nil
            }
        }
    }

    @ViewBuilder
    private var comparePairsListSection: some View {
        if trackedPeople.count < 2 {
            compareNeedMoreTrackedPeopleContent
        } else if visiblePairs.isEmpty {
            compareNoPairsOrResetContent
        } else {
            LazyVStack(spacing: 0) {
                ForEach(visiblePairs) { pair in
                    HStack(alignment: .center, spacing: 0) {
                        NavigationLink(value: pair) {
                            pairRowLeading(pair)
                        }
                        .buttonStyle(.plain)

                        pairRowMenu(pair: pair)
                    }

                    if pair.id != visiblePairs.last?.id {
                        Divider()
                            .background(AppTheme.divider)
                            .padding(.leading, 16)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.statisticsCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(AppTheme.divider, lineWidth: 1)
            )
        }
    }

    private var compareNeedMoreTrackedPeopleContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.badge.plus")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(AppTheme.lime)
            Text("Need at least two contacts")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
            Text("Follow two or more people on Last Seen to generate comparison pairs here.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.statisticsCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AppTheme.divider, lineWidth: 1)
        )
    }

    private var compareNoPairsOrResetContent: some View {
        VStack(spacing: 18) {
            Image(systemName: "rectangle.stack.badge.person.crop")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(AppTheme.lime)
            Text("No pairs in your list")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
            Text("Every pair was removed from this list. Reset to show all combinations again.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedText)
                .multilineTextAlignment(.center)

            Button {
                hiddenPairIds.removeAll()
            } label: {
                Text("Reset list")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.88))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.lime)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.statisticsCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AppTheme.divider, lineWidth: 1)
        )
    }

    private func personPickerCard(title: String, selection: Binding<FollowingContact?>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.mutedText)

            Menu {
                Button("Clear selection") {
                    selection.wrappedValue = nil
                }
                Divider()
                ForEach(trackedPeople) { person in
                    Button {
                        selection.wrappedValue = person
                    } label: {
                        if selection.wrappedValue?.id == person.id {
                            Label(person.name, systemImage: "checkmark")
                        } else {
                            Text(person.name)
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selection.wrappedValue?.name ?? "Choose someone…")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(selection.wrappedValue == nil ? AppTheme.mutedText : .white)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.mutedText)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.statisticsCard)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(AppTheme.lime.opacity(0.25), lineWidth: 1)
                )
            }
        }
    }

    private func pairRowLeading(_ pair: ComparisonPair) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: -6) {
                miniInitial(pair.contactA.initial)
                miniInitial(pair.contactB.initial)
            }

            Text(pair.pairDisplayTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            Spacer(minLength: 8)
        }
        .padding(.leading, 16)
        .padding(.vertical, 14)
        .padding(.trailing, 4)
        .contentShape(Rectangle())
    }

    private func pairRowMenu(pair: ComparisonPair) -> some View {
        Menu {
            Button {
                notificationContext = PairNotificationContext(
                    id: pair.id,
                    contactNameForSheet: pair.pairDisplayTitle
                )
            } label: {
                Label("More notification options", systemImage: "bell.badge")
            }

            Button(role: .destructive) {
                pairPendingRemoval = pair
            } label: {
                Label("Remove from tracking", systemImage: "person.fill.xmark")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.medium))
                .foregroundStyle(AppTheme.mutedText)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .padding(.trailing, 4)
        .accessibilityLabel("More options for \(pair.pairDisplayTitle)")
    }

    private func miniInitial(_ initial: String) -> some View {
        Text(initial.uppercased())
            .font(.caption2.weight(.bold))
            .foregroundStyle(AppTheme.lime)
            .frame(width: 28, height: 28)
            .background(Circle().fill(AppTheme.lime.opacity(0.15)))
            .overlay(Circle().strokeBorder(AppTheme.divider, lineWidth: 1))
    }
}

// MARK: - Detail (clock + stats)

private struct ComparePerson: Identifiable {
    let id: String
    let name: String
    let initial: String
    let phone: String
    var isOnline: Bool

    init(_ contact: FollowingContact, isOnline: Bool) {
        id = contact.id
        name = contact.name
        initial = contact.initial
        phone = contact.phoneDisplay
        self.isOnline = isOnline
    }
}

private struct OverlapArc: Identifiable {
    let id: Int
    let startTrim: CGFloat
    let endTrim: CGFloat
    let label: String
}

private enum ComparisonDummy {
    static let overlapSessionCount = 4
    static let overlapDurationLabel = "3h 6m"

    static let pmArcs: [OverlapArc] = [
        OverlapArc(id: 0, startTrim: 25 / 720, endTrim: 70 / 720, label: "12:25 – 1:10 PM"),
        OverlapArc(id: 1, startTrim: 200 / 720, endTrim: 285 / 720, label: "3:20 – 4:45 PM"),
        OverlapArc(id: 2, startTrim: 330 / 720, endTrim: 380 / 720, label: "5:30 – 6:20 PM"),
        OverlapArc(id: 3, startTrim: 420 / 720, endTrim: 460 / 720, label: "7:00 – 7:40 PM"),
    ]

    static let amArcs: [OverlapArc] = [
        OverlapArc(id: 0, startTrim: 50 / 720, endTrim: 110 / 720, label: "12:50 – 1:50 AM"),
        OverlapArc(id: 1, startTrim: 240 / 720, endTrim: 300 / 720, label: "4:00 – 5:00 AM"),
        OverlapArc(id: 2, startTrim: 400 / 720, endTrim: 455 / 720, label: "6:40 – 7:35 AM"),
    ]

    static func footerLines(personA: String, personB: String) -> [String] {
        [
            "\(personA) & \(personB) were online together during the highlighted periods on the clock.",
            "Total overlap: \(overlapDurationLabel) across \(overlapSessionCount) sessions on this day.",
        ]
    }
}

struct ComparisonDetailView: View {
    let contactA: FollowingContact
    let contactB: FollowingContact

    private var personLeft: ComparePerson {
        ComparePerson(contactA, isOnline: contactA.id.utf8.reduce(0) { $0 + Int($1) } % 2 == 0)
    }

    private var personRight: ComparePerson {
        ComparePerson(contactB, isOnline: contactB.id.utf8.reduce(0) { $0 + Int($1) } % 2 != 0)
    }

    @State private var selectedDate: Date
    @State private var useAfternoon = true
    @State private var showDatePicker = false
    @State private var highlightedArcId: Int?

    private var calendar: Calendar { Calendar.current }

    private var startOfToday: Date {
        calendar.startOfDay(for: Date())
    }

    private var selectedDayStart: Date {
        calendar.startOfDay(for: selectedDate)
    }

    private var canGoToNextDay: Bool {
        selectedDayStart < startOfToday
    }

    /// Earliest day both contacts were on the roster (comparison range starts then).
    private var earliestComparisonDay: Date {
        let a = calendar.startOfDay(for: contactA.trackedSince)
        let b = calendar.startOfDay(for: contactB.trackedSince)
        return min(max(a, b), startOfToday)
    }

    private var canGoToPreviousComparisonDay: Bool {
        selectedDayStart > earliestComparisonDay
    }

    init(contactA: FollowingContact, contactB: FollowingContact) {
        self.contactA = contactA
        self.contactB = contactB
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let a = cal.startOfDay(for: contactA.trackedSince)
        let b = cal.startOfDay(for: contactB.trackedSince)
        let ear = min(max(a, b), today)
        let initial = min(max(today, ear), today)
        _selectedDate = State(initialValue: initial)
    }

    private var arcs: [OverlapArc] {
        useAfternoon ? ComparisonDummy.pmArcs : ComparisonDummy.amArcs
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                profileRow
                dateSelectorRow
                summaryCards
                chartSection
                footerSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.automatic)
        .background(
            LinearGradient(
                colors: [Color.black, AppTheme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Comparison")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showDatePicker) {
            comparisonDatePickerSheet
        }
    }

    private var profileRow: some View {
        HStack(alignment: .center, spacing: 4) {
            compareProfileCard(person: personLeft)

            ZStack {
                Circle()
                    .fill(AppTheme.lime.opacity(0.18))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .strokeBorder(AppTheme.lime.opacity(0.45), lineWidth: 1)
                    )
                Text("&")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.lime)
            }
            .accessibilityLabel("And")

            compareProfileCard(person: personRight)
        }
    }

    private func compareProfileCard(person: ComparePerson) -> some View {
        VStack(spacing: 10) {
            Text(person.initial)
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.lime)
                .frame(width: 52, height: 52)
                .background(
                    Circle()
                        .fill(AppTheme.lime.opacity(0.12))
                )
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                )

            Text(person.name)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(person.phone)
                .font(.caption2)
                .foregroundStyle(AppTheme.mutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(spacing: 5) {
                Circle()
                    .fill(person.isOnline ? AppTheme.presenceOnline : AppTheme.mutedText.opacity(0.5))
                    .frame(width: 7, height: 7)
                Text(person.isOnline ? "Online" : "Offline")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(person.isOnline ? AppTheme.presenceOnline : AppTheme.mutedText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.statisticsCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AppTheme.divider, lineWidth: 1)
        )
    }

    private var dateSelectorRow: some View {
        HStack(spacing: 8) {
            Button {
                goToPreviousComparisonDay()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(canGoToPreviousComparisonDay ? AppTheme.lime : AppTheme.mutedText.opacity(0.35))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canGoToPreviousComparisonDay)
            .accessibilityLabel("Previous day")

            Button {
                showDatePicker = true
            } label: {
                Text(comparisonDateTitle)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choose date, \(comparisonDateTitle)")

            Button {
                goToNextComparisonDay()
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
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.statisticsCard)
        )
    }

    private var comparisonDateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = calendar.timeZone
        formatter.calendar = calendar
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: selectedDayStart)
    }

    private func goToPreviousComparisonDay() {
        guard canGoToPreviousComparisonDay else { return }
        if let previous = calendar.date(byAdding: .day, value: -1, to: selectedDayStart) {
            selectedDate = max(previous, earliestComparisonDay)
        }
    }

    private func goToNextComparisonDay() {
        guard canGoToNextDay else { return }
        if let next = calendar.date(byAdding: .day, value: 1, to: selectedDayStart) {
            selectedDate = min(next, startOfToday)
        }
    }

    private func clampComparisonDateToValidRange(_ date: Date) -> Date {
        let start = calendar.startOfDay(for: date)
        return min(max(start, earliestComparisonDay), startOfToday)
    }

    private var comparisonDatePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { selectedDayStart },
                        set: { selectedDate = clampComparisonDateToValidRange($0) }
                    ),
                    in: earliestComparisonDay...startOfToday,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.statisticsCard)
            .navigationTitle("Select date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.statisticsCard, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        selectedDate = clampComparisonDateToValidRange(selectedDate)
                        showDatePicker = false
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.lime)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(AppTheme.statisticsCard)
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }

    private var summaryCards: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Overlap online times")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.mutedText)
                Text("\(ComparisonDummy.overlapSessionCount)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.lime)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.statisticsCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(AppTheme.lime.opacity(0.35), lineWidth: 1)
            )

            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(ComparisonDummy.overlapDurationLabel)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.lime)
                    Text("Overlap duration")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.mutedText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)

                Image(systemName: "clock.fill")
                    .font(.title)
                    .foregroundStyle(AppTheme.lime.opacity(0.12))
                    .padding(10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.statisticsCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(AppTheme.lime.opacity(0.35), lineWidth: 1)
            )
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Charts")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Picker("", selection: $useAfternoon) {
                    Text("AM").tag(false)
                    Text("PM").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
                .tint(AppTheme.lime)
            }

            coincidentClock

            HStack(spacing: 8) {
                Circle()
                    .fill(AppTheme.lime)
                    .frame(width: 8, height: 8)
                Text("Coincident online periods")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.mutedText)
            }
            .padding(.top, 4)

            if let id = highlightedArcId, let arc = arcs.first(where: { $0.id == id }) {
                Text(arc.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.lime)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(AppTheme.statisticsInset)
                    )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.statisticsCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(AppTheme.divider, lineWidth: 1)
        )
    }

    private var coincidentClock: some View {
        let size: CGFloat = 240
        return ZStack {
            Circle()
                .stroke(AppTheme.mutedText.opacity(0.25), lineWidth: 1)
                .frame(width: size, height: size)

            Circle()
                .stroke(AppTheme.mutedText.opacity(0.15), lineWidth: 14)
                .frame(width: size * 0.82, height: size * 0.82)

            ForEach([12, 3, 6, 9], id: \.self) { hour in
                clockHourLabel(hour, diameter: size)
            }

            ForEach(arcs) { arc in
                Circle()
                    .trim(from: arc.startTrim, to: arc.endTrim)
                    .stroke(
                        highlightedArcId == arc.id ? AppTheme.lime : AppTheme.lime.opacity(0.85),
                        style: StrokeStyle(lineWidth: highlightedArcId == arc.id ? 14 : 10, lineCap: .round)
                    )
                    .frame(width: size * 0.96, height: size * 0.96)
                    .rotationEffect(.degrees(-90))
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            highlightedArcId = highlightedArcId == arc.id ? nil : arc.id
                        }
                    }
            }

            Circle()
                .fill(AppTheme.mutedText.opacity(0.35))
                .frame(width: 6, height: 6)
        }
        .frame(width: size, height: size)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Twelve hour clock showing coincident online periods")
    }

    private func clockHourLabel(_ hour: Int, diameter: CGFloat) -> some View {
        let angle = Double(hour % 12) / 12.0 * 2 * Double.pi - Double.pi / 2
        let r = diameter / 2 - 18
        let x = CGFloat(cos(angle)) * r
        let y = CGFloat(sin(angle)) * r
        return Text("\(hour)")
            .font(.caption.weight(.bold))
            .foregroundStyle(AppTheme.mutedText)
            .offset(x: x, y: y)
    }

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(personLeft.name) & \(personRight.name)'s coincident online summary")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)

            ForEach(ComparisonDummy.footerLines(personA: personLeft.name, personB: personRight.name), id: \.self) { line in
                Text("• \(line)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(arcs) { arc in
                    Text(arc.label)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.mutedText)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(AppTheme.statisticsInset)
                        )
                }
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.statisticsCard)
        )
    }
}

#Preview("Hub") {
    NavigationStack {
        ComparisonView()
            .environmentObject(ContactTrackingStore())
    }
}

#Preview("Detail") {
    NavigationStack {
        ComparisonDetailView(
            contactA: FollowingContact(
                id: "a",
                name: "Shera",
                initial: "S",
                lastSeenRelative: "",
                phoneDisplay: "+1 415 555 0140",
                trackedSince: Calendar.current.date(byAdding: .day, value: -21, to: Date()) ?? Date()
            ),
            contactB: FollowingContact(
                id: "b",
                name: "Barret",
                initial: "B",
                lastSeenRelative: "",
                phoneDisplay: "+1 628 555 0199",
                trackedSince: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            )
        )
    }
}
