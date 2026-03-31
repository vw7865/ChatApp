//
//  BackendConfiguration.swift
//  ChatAppTracker
//

import Foundation

/// Reads `APIBaseURL` from Info.plist (set per build configuration). If unset or empty, API calls are skipped.
enum BackendConfiguration {
    static var apiBaseURL: URL? {
        guard let s = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String else { return nil }
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return nil }
        return url
    }

    /// Optional API key used for `x-api-key` authentication in companion-link flows.
    static var apiKey: String? {
        guard let s = Bundle.main.object(forInfoDictionaryKey: "APIKey") as? String else { return nil }
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
