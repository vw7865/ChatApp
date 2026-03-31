//
//  ContactTrackingStore.swift
//  ChatAppTracker
//

import SwiftUI

/// Shared UI state for who the user is “tracking” (Last Seen, Compare, etc.). Replace with persistence later.
@MainActor
final class ContactTrackingStore: ObservableObject {
    /// Online spotlight row (e.g. Tommy).
    let spotlightContact: FollowingContact

    @Published var showOnlinePerson: Bool
    @Published var offlineFollowing: [FollowingContact]

    /// Full demo roster. Order: spotlight first, then offline defaults.
    static var contactDirectory: [FollowingContact] {
        [spotlightTemplate] + defaultOfflineFollowing
    }

    private static func demoTrackedStart(daysAgo: Int) -> Date {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        return cal.date(byAdding: .day, value: -daysAgo, to: todayStart) ?? todayStart
    }

    private static let spotlightTemplate = FollowingContact(
        id: "tommy",
        name: "Tommy",
        initial: "T",
        lastSeenRelative: "5 seconds ago",
        phoneDisplay: "+1 875 123 34 45",
        trackedSince: demoTrackedStart(daysAgo: 40)
    )

    init() {
        spotlightContact = Self.spotlightTemplate
        showOnlinePerson = true
        offlineFollowing = Self.defaultOfflineFollowing
    }

    private static let defaultOfflineFollowing: [FollowingContact] = [
        FollowingContact(id: "carl", name: "Carl", initial: "C", lastSeenRelative: "19 minutes ago", phoneDisplay: "+1 234 567 8901", trackedSince: demoTrackedStart(daysAgo: 32)),
        FollowingContact(id: "belian", name: "Belian", initial: "B", lastSeenRelative: "24 minutes ago", phoneDisplay: "+44 20 7946 0958", trackedSince: demoTrackedStart(daysAgo: 28)),
        FollowingContact(id: "maya", name: "Maya", initial: "M", lastSeenRelative: "32 minutes ago", phoneDisplay: "+1 415 555 0199", trackedSince: demoTrackedStart(daysAgo: 24)),
        FollowingContact(id: "james", name: "James", initial: "J", lastSeenRelative: "1 hour ago", phoneDisplay: "+1 312 555 0142", trackedSince: demoTrackedStart(daysAgo: 20)),
        FollowingContact(id: "sofia", name: "Sofia", initial: "S", lastSeenRelative: "2 hours ago", phoneDisplay: "+34 612 34 56 78", trackedSince: demoTrackedStart(daysAgo: 18)),
        FollowingContact(id: "wei", name: "Wei", initial: "W", lastSeenRelative: "3 hours ago", phoneDisplay: "+86 138 0013 8000", trackedSince: demoTrackedStart(daysAgo: 15)),
        FollowingContact(id: "olivia", name: "Olivia", initial: "O", lastSeenRelative: "Yesterday", phoneDisplay: "+61 412 345 678", trackedSince: demoTrackedStart(daysAgo: 12)),
        FollowingContact(id: "diego", name: "Diego", initial: "D", lastSeenRelative: "Yesterday", phoneDisplay: "+52 55 1234 5678", trackedSince: demoTrackedStart(daysAgo: 10)),
        FollowingContact(id: "emma", name: "Emma", initial: "E", lastSeenRelative: "2 days ago", phoneDisplay: "+49 151 23456789", trackedSince: demoTrackedStart(daysAgo: 7)),
        FollowingContact(id: "noah", name: "Noah", initial: "N", lastSeenRelative: "4 days ago", phoneDisplay: "+1 604 555 0188", trackedSince: demoTrackedStart(daysAgo: 5)),
        FollowingContact(id: "priya", name: "Priya", initial: "P", lastSeenRelative: "1 week ago", phoneDisplay: "+91 98765 43210", trackedSince: demoTrackedStart(daysAgo: 3)),
    ]

    var isTrackingEmpty: Bool {
        !showOnlinePerson && offlineFollowing.isEmpty
    }

    /// Everyone shown on Last Seen / Compare (online first, then offline, no duplicates).
    func allTrackedContacts() -> [FollowingContact] {
        var out: [FollowingContact] = []
        if showOnlinePerson {
            out.append(spotlightContact)
        }
        for c in offlineFollowing where !out.contains(where: { $0.id == c.id }) {
            out.append(c)
        }
        return out
    }

    func removeFromTracking(_ contact: FollowingContact) {
        if contact.id == spotlightContact.id {
            showOnlinePerson = false
        } else {
            offlineFollowing.removeAll { $0.id == contact.id }
        }
    }

    /// Contacts from the directory that are not currently in the following list.
    func contactsNotYetFollowing() -> [FollowingContact] {
        let trackedIds = Set(allTrackedContacts().map(\.id))
        return Self.contactDirectory.filter { !trackedIds.contains($0.id) }
    }

    func addToTracking(_ contact: FollowingContact) {
        if contact.id == spotlightContact.id {
            showOnlinePerson = true
            return
        }
        guard !offlineFollowing.contains(where: { $0.id == contact.id }) else { return }
        let since = Calendar.current.startOfDay(for: Date())
        let added = FollowingContact(
            id: contact.id,
            name: contact.name,
            initial: contact.initial,
            lastSeenRelative: contact.lastSeenRelative,
            phoneDisplay: contact.phoneDisplay,
            trackedSince: since
        )
        offlineFollowing.append(added)
    }

    /// Adds a user-entered contact (from the Add someone flow).
    func addCustomContact(name: String, phoneDisplay: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let initialChar = trimmed.first.map { String($0).uppercased() } ?? "?"
        let since = Calendar.current.startOfDay(for: Date())
        let c = FollowingContact(
            id: UUID().uuidString,
            name: trimmed,
            initial: initialChar,
            lastSeenRelative: "Just added",
            phoneDisplay: phoneDisplay,
            trackedSince: since
        )
        guard !offlineFollowing.contains(where: { $0.id == c.id }) else { return }
        offlineFollowing.append(c)
    }
}
